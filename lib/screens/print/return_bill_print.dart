import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/screens/print/return_bill_print_thermal.dart';
import 'package:pos_machine/screens/print/return_bill_print_standard.dart';
import 'package:pos_machine/screens/print/receipt_customer_segment.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/services/printer_permission_service.dart';

class ReturnBillPrintPage extends StatefulWidget {
  final List<OrderReturnItem> returnItems;
  final List<OrderDetailsModelDataCartItem>? originalCartItems;
  final String? storeName;
  final String returnTotalAmount;
  final String orderDate;
  final String orderNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? customerBalance;
  final String? customerVatNumber;
  final String? customerCrNumber;
  final String? customerType;

  const ReturnBillPrintPage({
    super.key,
    required this.returnItems,
    this.originalCartItems,
    required this.returnTotalAmount,
    this.storeName,
    required this.orderDate,
    required this.orderNumber,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.customerBalance,
    this.customerVatNumber,
    this.customerCrNumber,
    this.customerType,
  });

  @override
  _ReturnBillPrintPageState createState() => _ReturnBillPrintPageState();
}

class _ReturnBillPrintPageState extends State<ReturnBillPrintPage> {
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  BluetoothPrinter? selectedPrinter;
  bool _isScanning = false;
  bool _isLoading = true;
  String selectedPaperSize = '80mm';

  DocumentConfig? _returnBillDocumentConfig;

  bool get _isB2B => ReceiptCustomerSegment.isBusiness(
        customerType: widget.customerType,
        vatNumber: widget.customerVatNumber,
        crNumber: widget.customerCrNumber,
      );

  String get _printerPrefsKey =>
      _isB2B ? 'default_printer_b2b' : 'default_printer';

  String get _paperSizePrefsKey =>
      _isB2B ? 'default_paper_size_b2b' : 'default_paper_size';

  String get _themePrefsKey =>
      _isB2B ? 'billing_receipt_theme_b2b' : 'billing_receipt_theme';

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
        '[ReturnBillPrintPage] dispose(): canceling discovery subscription if any');
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    debugPrint('[ReturnBillPrintPage] _checkPermissions() called');
    if (await _requestPermissions()) {
      debugPrint(
          '[ReturnBillPrintPage] Permissions granted. Proceeding to scan.');
      _scan();
    } else {
      debugPrint(
          '[ReturnBillPrintPage] Permissions NOT granted. Showing dialog.');
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    debugPrint(
        '[ReturnBillPrintPage] _requestPermissions() platform(os)=${Platform.operatingSystem} theme=${Theme.of(context).platform}');
    if (Platform.isAndroid) {
      final granted =
          await PrinterPermissionService.requestRequiredPermissions();
      debugPrint('[ReturnBillPrintPage] All permissions granted: $granted');
      return granted;
    }
    debugPrint(
        '[ReturnBillPrintPage] Non-Android platform; skipping runtime permission request.');
    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ui_codes.permissions_required'.tr),
        content: Text('voucher_print.printer_permissions_required'.tr),
        actions: [
          TextButton(
            child: Text('general.ok'.tr),
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
          '[ReturnBillPrintPage] _scan() requested but a scan is already in progress. Ignoring.');
      return;
    }
    debugPrint(
        '[ReturnBillPrintPage] Starting scan... platform=${Platform.operatingSystem}');
    await _subscription?.cancel();
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Bluetooth discovery only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint(
            '[ReturnBillPrintPage] Beginning Bluetooth discovery (isBle=false)');
        _subscription = printerManager
            .discovery(type: PrinterType.bluetooth, isBle: false)
            .listen((device) {
          debugPrint(
              '[ReturnBillPrintPage] BT device found: name=${device.name}, address=${device.address}');
          final printer = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            typePrinter: PrinterType.bluetooth,
          );
          setState(() {
            devices.add(printer);
          });
        }, onError: (err) {
          debugPrint('[ReturnBillPrintPage] Bluetooth discovery error: $err');
        }, onDone: () {
          final btCount = devices
              .where((p) => p.typePrinter == PrinterType.bluetooth)
              .length;
          debugPrint(
              '[ReturnBillPrintPage] Bluetooth discovery done. Total BT devices: $btCount');
        }, cancelOnError: false);
      } else {
        debugPrint(
            '[ReturnBillPrintPage] Skipping Bluetooth discovery on desktop platform (${Platform.operatingSystem}).');
      }

      debugPrint('[ReturnBillPrintPage] Beginning USB discovery');
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        debugPrint(
            '[ReturnBillPrintPage] USB device found: name=${device.name}, vendorId=${device.vendorId}, productId=${device.productId}');
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
          '[ReturnBillPrintPage] USB discovery completed. Total devices now: ${devices.length}');
    } catch (e, st) {
      debugPrint('[ReturnBillPrintPage] Error during scanning: $e');
      debugPrint('[ReturnBillPrintPage] Stacktrace: $st');
    } finally {
      setState(() {
        _isScanning = false;
      });
      debugPrint(
          '[ReturnBillPrintPage] Scan finished. devices.length=${devices.length}');
    }
  }

  Future<void> _loadDefaultPrinter() async {
    debugPrint(
        '[ReturnBillPrintPage] _loadDefaultPrinter() reading from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson =
        prefs.getString(_printerPrefsKey) ?? prefs.getString('default_printer');

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
          '[ReturnBillPrintPage] Default printer loaded: name=${selectedPrinter?.deviceName}, address=${selectedPrinter?.address}, type=${selectedPrinter?.typePrinter}');

      if (selectedPrinter != null && _returnBillDocumentConfig != null) {
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
      debugPrint(
          '[ReturnBillPrintPage] No default printer found in SharedPreferences');
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
    await prefs.setString(_printerPrefsKey, json.encode(printerData));
  }

  void selectPrinter(BluetoothPrinter printer) {
    debugPrint(
        '[ReturnBillPrintPage] selectPrinter(): name=${printer.deviceName}, address=${printer.address}, type=${printer.typePrinter}');
    setState(() {
      selectedPrinter = printer;
    });

    _saveDefaultPrinter(printer);

    if (mounted) {
      showScaffold(
        context: context,
        message: 'voucher_print.printer_selected'.trParams({
          'name': printer.deviceName.toString(),
        }),
      );
    }
  }

  Future<void> _loadDocumentConfigurationsFromProvider() async {
    try {
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      debugPrint(
          "Loading Return Bill document configurations from provider...");

      _returnBillDocumentConfig =
          docConfigProvider.getDocumentConfig("Credit Note") ??
              docConfigProvider.getDocumentConfig("Return Bill");

      if (_returnBillDocumentConfig == null) {
        debugPrint(
            "WARNING: Credit Note/Return Bill document configuration not found in provider, may need to load manually");
        // Fallback: try to load if not available
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null) {
          debugPrint("Fetching document configurations from API...");
          await _loadDocumentConfigurations(accessToken);
          return;
        }
      } else {
        debugPrint(
            "SUCCESS: Return Bill document configuration loaded from provider");
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("ERROR getting document configurations from provider: $e");
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

      debugPrint(
          "Loading 'Credit Note'/'Return Bill' configuration from API...");
      _returnBillDocumentConfig =
          docConfigProvider.getDocumentConfig("Credit Note") ??
              docConfigProvider.getDocumentConfig("Return Bill");

      if (_returnBillDocumentConfig != null) {
        debugPrint(
            "SUCCESS: Return Bill document configuration loaded from API");
      } else {
        debugPrint(
            "ERROR: Return Bill document configuration still null after API fetch");
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
          message: 'voucher_print.error_loading_document_config'.trParams(
            {'error': e.toString()},
          ),
        );
      }
    }
  }

  Future<void> _handlePrinting(
      String customerCareNumber, String customerCareEmail) async {
    if (_returnBillDocumentConfig == null) {
      debugPrint("ERROR: Return Bill document configuration not loaded yet.");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.document_config_not_loaded_retry'.tr,
        );
      }
      return;
    }

    final theme = await _getReceiptTheme();
    debugPrint(
        '[ReturnBillPrintPage] Using return theme=$theme, config=${_returnBillDocumentConfig?.type}, isB2B=$_isB2B');

    if (selectedPaperSize == '112mm' ||
        selectedPaperSize == '80mm' ||
        selectedPaperSize == '58mm') {
      await _printThermalReceipt(customerCareNumber, customerCareEmail, theme);
    } else {
      await _generateAndPrintPDF(customerCareNumber, customerCareEmail, theme);
    }
  }

  Future<void> _printThermalReceipt(
      String customerCareNumber, String customerCareEmail, String theme) async {
    final thermalPrinter = ReturnBillThermalPrinter(context);

    await thermalPrinter.printReturnBill(
      selectedPrinter: selectedPrinter!,
      returnItems: widget.returnItems,
      originalCartItems: widget.originalCartItems,
      returnTotalAmount: widget.returnTotalAmount,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      selectedPaperSize: selectedPaperSize,
      returnBillDocumentConfig: _returnBillDocumentConfig,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      customerEmail: widget.customerEmail,
      customerAddress: widget.customerAddress,
      customerBalance: widget.customerBalance,
      customerVatNumber: widget.customerVatNumber,
      customerCrNumber: widget.customerCrNumber,
      customerType: widget.customerType,
      theme: theme,
    );
  }

  Future<void> _generateAndPrintPDF(
      String customerCareNumber, String customerCareEmail, String theme) async {
    final standardPrinter = ReturnBillStandardPrinter(context);

    await standardPrinter.generateAndPrintPDF(
      selectedPrinter: selectedPrinter,
      returnItems: widget.returnItems,
      originalCartItems: widget.originalCartItems,
      returnTotalAmount: widget.returnTotalAmount,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      selectedPaperSize: selectedPaperSize,
      returnBillDocumentConfig: _returnBillDocumentConfig,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      customerEmail: widget.customerEmail,
      customerAddress: widget.customerAddress,
      customerBalance: widget.customerBalance,
      customerVatNumber: widget.customerVatNumber,
      customerCrNumber: widget.customerCrNumber,
      customerType: widget.customerType,
      theme: theme,
    );
  }

  Future<String> _getReceiptTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final localTheme = prefs.getString(_themePrefsKey) ??
        prefs.getString('billing_receipt_theme');
    if (localTheme != null && localTheme.trim().isNotEmpty) {
      return localTheme.trim();
    }

    final apiTheme = _returnBillDocumentConfig?.activeTheme;
    if (apiTheme != null && apiTheme.trim().isNotEmpty) {
      return apiTheme.trim();
    }
    return 'classic';
  }

  Future<void> _loadDefaultPaperSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPaperSize = prefs.getString(_paperSizePrefsKey) ??
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
    await prefs.setString(_paperSizePrefsKey, paperSize);

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
        title: Text(
          'voucher_print.print_return_bill'.tr,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'voucher_print.paper_size'.tr,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPaperSize,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'voucher_print.available_printers'.tr,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning
                          ? 'voucher_print.scanning'.tr
                          : 'voucher_print.info_devices_found'.trParams({
                              'count': devices.length.toString(),
                            }),
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
                          Text(
                            'voucher_print.no_printers_found'.tr,
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'voucher_print.tap_refresh_to_scan'.tr,
                            style: TextStyle(
                              color: textSecondaryColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
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
                          elevation: isSelected ? 3 : 1,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: isSelected
                                ? BorderSide(color: primaryColor, width: 2)
                                : BorderSide.none,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isSelected
                                  ? primaryColor.withOpacity(0.05)
                                  : Colors.white,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Icon(
                                Icons.print,
                                color: isSelected
                                    ? primaryColor
                                    : textSecondaryColor,
                                size: 32,
                              ),
                              title: Text(
                                printer.deviceName ??
                                    'voucher_print.unknown_device'.tr,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                printer.address ?? 'general.not_available'.tr,
                                style: const TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? accentColor
                                      : Colors.grey[300],
                                  foregroundColor: isSelected
                                      ? Colors.white
                                      : textSecondaryColor,
                                  elevation: isSelected ? 2 : 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () => selectPrinter(printer),
                                child: Text(
                                  isSelected
                                      ? 'voucher_print.selected'.tr
                                      : 'voucher_print.select'.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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
            if (_returnBillDocumentConfig == null)
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
                    Icon(Icons.info_outline,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'voucher_print.loading_document_config'.tr,
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                        'general.retry'.tr,
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
                if (selectedPrinter == null) {
                  showScaffoldError(
                    context: context,
                    message: 'voucher_print.select_printer_first'.tr,
                  );
                  return;
                }
                if (_returnBillDocumentConfig == null) {
                  showScaffoldError(
                    context: context,
                    message:
                        'voucher_print.document_config_not_loaded_retry'.tr,
                  );
                  return;
                }
                _handlePrinting(appSettings!.customerCarePhone,
                    appSettings.customerCareEmail);
              },
              icon: const Icon(Icons.receipt_long, size: 20),
              label: Text(
                'voucher_print.print_return_bill'.tr,
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _checkPermissions,
        tooltip: 'voucher_print.scan_for_printers'.tr,
        backgroundColor: _isScanning ? textSecondaryColor : primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
