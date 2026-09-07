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
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print_thermal.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report_print_standard.dart';
import 'package:share_plus/share_plus.dart';

class SupplierTransactionReportPrint extends StatefulWidget {
  final List<SupplierTransaction> cartItems;
  final bool isFromLocalStorage;
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierEmail;
  final String? supplierAddress;
  final String formattedTotal;
  final String? savedTotal;
  final String orderDate;
  final String orderNumber;
  final String? fromDate;
  final String? toDate;

  const SupplierTransactionReportPrint({
    Key? key,
    required this.cartItems,
    this.isFromLocalStorage = false,
    this.supplierName,
    this.supplierPhone,
    this.supplierEmail,
    this.supplierAddress,
    required this.formattedTotal,
    this.savedTotal,
    required this.orderDate,
    required this.orderNumber,
    this.fromDate,
    this.toDate,
  }) : super(key: key);

  @override
  _SupplierTransactionReportPrintState createState() =>
      _SupplierTransactionReportPrintState();
}

class _SupplierTransactionReportPrintState
    extends State<SupplierTransactionReportPrint> {
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  BluetoothPrinter? selectedPrinter;
  bool _isScanning = false;
  bool _isLoading = true;
  String selectedPaperSize = '80mm';

  DocumentConfig? _supplierStatementDocumentConfig;

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
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      _subscription = printerManager
          .discovery(type: PrinterType.bluetooth, isBle: false)
          .listen((device) {
        final printer = BluetoothPrinter(
          deviceName: device.name,
          address: device.address,
          typePrinter: PrinterType.bluetooth,
        );
        setState(() {
          devices.add(printer);
        });
      });

      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
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
      debugPrint('Error during scanning: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _loadDefaultPrinter() async {
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

      if (selectedPrinter != null && _supplierStatementDocumentConfig != null) {
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

      debugPrint("Loading document configurations from provider...");
      _supplierStatementDocumentConfig =
          docConfigProvider.getDocumentConfig("Supplier Statement");

      if (_supplierStatementDocumentConfig == null) {
        debugPrint(
            "WARNING: Supplier Statement document configuration not found in provider, may need to load manually");
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
            "SUCCESS: Supplier Statement document configuration loaded from provider");
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

      _supplierStatementDocumentConfig =
          docConfigProvider.getDocumentConfig("Supplier Statement");

      if (_supplierStatementDocumentConfig != null) {
        debugPrint(
            "SUCCESS: Supplier Statement document configuration loaded from API");
      } else {
        debugPrint(
            "ERROR: Supplier Statement document configuration still null after API fetch");
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
    if (_supplierStatementDocumentConfig == null) {
      debugPrint(
          "ERROR: Supplier Statement document configuration not loaded yet.");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.document_config_not_loaded_retry'.tr,
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
    final thermalPrinter = SupplierTransactionReportThermalPrinter(context);

    await thermalPrinter.printSupplierTransactionReport(
      selectedPrinter: selectedPrinter!,
      cartItems: widget.cartItems,
      formattedTotal: widget.formattedTotal,
      savedTotal: widget.savedTotal,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      isFromLocalStorage: widget.isFromLocalStorage,
      selectedPaperSize: selectedPaperSize,
      billDocumentConfig: _supplierStatementDocumentConfig,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      supplierName: widget.supplierName,
      supplierPhone: widget.supplierPhone,
      supplierEmail: widget.supplierEmail,
      supplierAddress: widget.supplierAddress,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );
  }

  Future<void> _generateAndPrintPDF(
      String customerCareNumber, String customerCareEmail) async {
    final standardPrinter = SupplierTransactionReportStandardPrinter(context);

    await standardPrinter.generateAndPrintSupplierTransactionReportPDF(
      selectedPrinter: selectedPrinter,
      cartItems: widget.cartItems,
      formattedTotal: widget.formattedTotal,
      savedTotal: widget.savedTotal,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      isFromLocalStorage: widget.isFromLocalStorage,
      selectedPaperSize: selectedPaperSize,
      billDocumentConfig: _supplierStatementDocumentConfig,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      supplierName: widget.supplierName,
      supplierPhone: widget.supplierPhone,
      supplierEmail: widget.supplierEmail,
      supplierAddress: widget.supplierAddress,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );
  }

  Future<void> _handleSharing(
      String customerCareNumber, String customerCareEmail) async {
    if (_supplierStatementDocumentConfig == null) {
      debugPrint(
          "ERROR: Supplier Statement document configuration not loaded yet.");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'voucher_print.document_config_not_loaded_retry'.tr,
        );
      }
      return;
    }

    final standardPrinter = SupplierTransactionReportStandardPrinter(context);

    final File? pdfFile =
        await standardPrinter.generateSupplierTransactionReportPDFForSharing(
      cartItems: widget.cartItems,
      formattedTotal: widget.formattedTotal,
      savedTotal: widget.savedTotal,
      orderDate: widget.orderDate,
      orderNumber: widget.orderNumber,
      isFromLocalStorage: widget.isFromLocalStorage,
      selectedPaperSize: selectedPaperSize,
      billDocumentConfig: _supplierStatementDocumentConfig,
      customerCareNumber: customerCareNumber,
      customerCareEmail: customerCareEmail,
      supplierName: widget.supplierName,
      supplierPhone: widget.supplierPhone,
      supplierEmail: widget.supplierEmail,
      supplierAddress: widget.supplierAddress,
      fromDate: widget.fromDate,
      toDate: widget.toDate,
    );

    if (pdfFile != null && await pdfFile.exists()) {
      try {
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          subject: 'Supplier Transaction Report #${widget.orderNumber}',
          text: 'Please find the attached supplier transaction report.',
        );
      } catch (e) {
        debugPrint("Error sharing PDF: ${e.toString()}");
        if (mounted) {
          showScaffoldError(
            context: context,
            message: "Error sharing PDF: ${e.toString()}",
          );
        }
      }
    } else {
      debugPrint("Error: PDF file was not generated properly");
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF for sharing",
        );
      }
    }
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
        title: Text(
          'supplier_transaction_report.print_supplier_transaction_report'.tr,
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
                    Text(
                      'voucher_print.paper_size'.tr,
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
                    Text(
                      'voucher_print.available_printers'.tr,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning
                          ? 'voucher_print.scanning'.tr
                          : 'voucher_print.info_devices_found'.trParams(
                              {'count': devices.length.toString()}),
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
                              color: textSecondaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'voucher_print.tap_refresh_to_scan'.tr,
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
                                printer.deviceName ??
                                    'voucher_print.unknown_device'.tr,
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
                                  isSelected
                                      ? 'voucher_print.selected'.tr
                                      : 'voucher_print.select'.tr,
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
            if (_supplierStatementDocumentConfig == null)
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
                        'voucher_print.loading_document_config'.tr,
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
                if (_supplierStatementDocumentConfig == null) {
                  showScaffoldError(
                    context: context,
                    message: 'voucher_print.document_config_missing'.tr,
                  );
                  return;
                }
                _handlePrinting(appSettings!.customerCarePhone,
                    appSettings.customerCareEmail);
              },
              icon: const Icon(Icons.receipt_long),
              label: Text(
                'supplier_transaction_report.print_supplier_transaction_report'.tr,
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (_supplierStatementDocumentConfig == null) {
                  showScaffoldError(
                    context: context,
                    message: 'voucher_print.document_config_missing'.tr,
                  );
                  return;
                }
                _handleSharing(appSettings!.customerCarePhone,
                    appSettings.customerCareEmail);
              },
              icon: const Icon(Icons.share),
              label: Text(
                'supplier_transaction_report.share_supplier_transaction_report'.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
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
        tooltip: 'voucher_print.scan_for_printers'.tr,
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