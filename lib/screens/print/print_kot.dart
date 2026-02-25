import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/auth_model.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/screens/print/kot_thermal_printer.dart';
import 'package:pos_machine/screens/print/kot_standard_printer.dart';

/// Kitchen Order Ticket Print Page
/// Supports both thermal (58mm/80mm) and standard (A4/A5) printing
class KotPrintPage extends StatefulWidget {
  final String orderNumber;
  final String? tokenNumber;
  final String tableName;
  final String orderTime;
  final List<Map<String, dynamic>> items;
  final String? comment;
  final bool showTableLabel;

  const KotPrintPage({
    super.key,
    required this.orderNumber,
    this.tokenNumber,
    required this.tableName,
    required this.orderTime,
    required this.items,
    this.comment,
    this.showTableLabel = true,
  });

  @override
  State<KotPrintPage> createState() => _KotPrintPageState();

  /// Auto-print KOT with default printer without showing UI
  /// Returns true if printing succeeded, false if no printer or failed
  static Future<bool> autoPrint(BuildContext context, {
    required String orderNumber,
    String? tokenNumber,
    required String tableName,
    required String orderTime,
    required List<Map<String, dynamic>> items,
    String? comment,
    bool showTableLabel = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try KOT printer first, fallback to default printer
      String? printerJson = prefs.getString('kot_printer');
      if (printerJson == null) {
        printerJson = prefs.getString('default_printer');
      }

      if (printerJson == null) {
        debugPrint('[KotPrintPage] No default printer found');
        return false;
      }

      final Map<String, dynamic> printerData = json.decode(printerJson);
      final selectedPrinter = BluetoothPrinter(
        deviceName: printerData['deviceName'],
        address: printerData['address'],
        vendorId: printerData['vendorId'],
        productId: printerData['productId'],
        typePrinter: PrinterType.values.firstWhere(
          (e) => e.toString() == printerData['typePrinter'],
        ),
      );

      debugPrint('[KotPrintPage] Auto-printing KOT with printer: ${selectedPrinter.deviceName}');

      // Load document config from cache (NO API CALL - instant!)
      final docConfigProvider = Provider.of<DocumentConfigProvider>(context, listen: false);
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;

      DocumentConfig? kotDocumentConfig;

      // Try multiple config name patterns to find cached config
      kotDocumentConfig = docConfigProvider.getCachedConfig("Kitchen Order") ??
                         docConfigProvider.getCachedConfig("kitchen_order");

      if (kotDocumentConfig == null) {
        debugPrint('[KotPrintPage] Document config not loaded');
        return false;
      }

      // Get paper size
      String paperSize = prefs.getString('kot_paper_size') ?? '80mm';
      if (paperSize == null || paperSize.isEmpty) {
        paperSize = prefs.getString('default_paper_size') ?? '80mm';
      }
      if (paperSize == 'Thermal') {
        paperSize = '80mm';
      }

      // Print
      if (paperSize == '112mm' || paperSize == '80mm' || paperSize == '58mm') {
        final kotPrinter = KotThermalPrinter(context);
        String formattedTime = DateHelper.formatISODateToIST(orderTime);

        await kotPrinter.printKot(
          selectedPrinter: selectedPrinter,
          orderNumber: orderNumber,
          tokenNumber: tokenNumber,
          tableName: tableName,
          showTableLabel: showTableLabel,
          orderTime: formattedTime,
          items: items,
          comment: comment,
          selectedPaperSize: paperSize,
          kotDocumentConfig: kotDocumentConfig,
        );
      } else {
        final kotStandardPrinter = KotStandardPrinter(context);
        String formattedTime = DateHelper.formatISODateToIST(orderTime);

        await kotStandardPrinter.generateAndPrintKotPDF(
          orderNumber: orderNumber,
          tokenNumber: tokenNumber,
          tableName: tableName,
          showTableLabel: showTableLabel,
          orderTime: formattedTime,
          items: items,
          comment: comment,
          selectedPaperSize: paperSize,
          kotDocumentConfig: kotDocumentConfig,
        );
      }

      debugPrint('[KotPrintPage] Auto-print successful');
      return true;
    } catch (e) {
      debugPrint('[KotPrintPage] Auto-print failed: $e');
      return false;
    }
  }
}

class _KotPrintPageState extends State<KotPrintPage> {
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  BluetoothPrinter? selectedPrinter;
  bool _isScanning = false;
  bool _isLoading = true;
  String selectedPaperSize = '80mm';

  DocumentConfig? _kotDocumentConfig;

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
        '[KotPrintPage] dispose(): canceling discovery subscription if any');
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    debugPrint('[KotPrintPage] _checkPermissions() called');
    if (await _requestPermissions()) {
      debugPrint('[KotPrintPage] Permissions granted. Proceeding to scan.');
      _scan();
    } else {
      debugPrint('[KotPrintPage] Permissions NOT granted. Showing dialog.');
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    debugPrint(
        '[KotPrintPage] _requestPermissions() platform(os)=${Platform.operatingSystem} theme=${Theme.of(context).platform}');
    if (Theme.of(context).platform == TargetPlatform.android) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      statuses.forEach((perm, status) {
        debugPrint(
            '[KotPrintPage] Permission ${perm.toString()} => ${status.toString()}');
      });

      final granted = statuses.values.every((status) => status.isGranted);
      debugPrint('[KotPrintPage] All permissions granted: $granted');
      return granted;
    }
    debugPrint(
        '[KotPrintPage] Non-Android platform; skipping runtime permission request.');
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
          '[KotPrintPage] _scan() requested but a scan is already in progress. Ignoring.');
      return;
    }
    debugPrint(
        '[KotPrintPage] Starting scan... platform=${Platform.operatingSystem}');
    await _subscription?.cancel();
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Bluetooth discovery only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint(
            '[KotPrintPage] Beginning Bluetooth discovery (isBle=false)');
        _subscription = printerManager
            .discovery(type: PrinterType.bluetooth, isBle: false)
            .listen((device) {
          debugPrint(
              '[KotPrintPage] BT device found: name=${device.name}, address=${device.address}');
          final printer = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            typePrinter: PrinterType.bluetooth,
          );
          setState(() {
            devices.add(printer);
          });
        }, onError: (err) {
          debugPrint('[KotPrintPage] Bluetooth discovery error: $err');
        }, onDone: () {
          final btCount = devices
              .where((p) => p.typePrinter == PrinterType.bluetooth)
              .length;
          debugPrint(
              '[KotPrintPage] Bluetooth discovery done. Total BT devices: $btCount');
        }, cancelOnError: false);
      } else {
        debugPrint(
            '[KotPrintPage] Skipping Bluetooth discovery on desktop platform (${Platform.operatingSystem}).');
      }

      debugPrint('[KotPrintPage] Beginning USB discovery');
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        debugPrint(
            '[KotPrintPage] USB device found: name=${device.name}, vendorId=${device.vendorId}, productId=${device.productId}');
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
          '[KotPrintPage] USB discovery completed. Total devices now: ${devices.length}');
    } catch (e, st) {
      debugPrint('[KotPrintPage] Error during scanning: $e');
      debugPrint('[KotPrintPage] Stacktrace: $st');
    } finally {
      setState(() {
        _isScanning = false;
      });
      debugPrint(
          '[KotPrintPage] Scan finished. devices.length=${devices.length}');
    }
  }

  Future<void> _loadDefaultPrinter() async {
    debugPrint(
        '[KotPrintPage] _loadDefaultPrinter() reading from SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    // Try to load KOT specific printer first
    String? printerJson = prefs.getString('kot_printer');

    // Fallback to default printer if KOT printer is not set
    if (printerJson == null) {
      debugPrint(
          '[KotPrintPage] No KOT printer found. Falling back to default printer.');
      printerJson = prefs.getString('default_printer');
    }

    if (printerJson != null) {
      final Map<String, dynamic> printerData = json.decode(printerJson);

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
          '[KotPrintPage] Printer loaded: name=${selectedPrinter?.deviceName}, address=${selectedPrinter?.address}, type=${selectedPrinter?.typePrinter}');

      if (selectedPrinter != null && _kotDocumentConfig != null) {
        // Note: Auto-print is now handled by static autoPrint() method
        // The page will only be shown if auto-print fails or no printer is set
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint('[KotPrintPage] No printer found in SharedPreferences');
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
    // Save to 'kot_printer' instead of 'default_printer'
    await prefs.setString('kot_printer', json.encode(printerData));
  }

  void selectPrinter(BluetoothPrinter printer) {
    debugPrint(
        '[KotPrintPage] selectPrinter(): name=${printer.deviceName}, address=${printer.address}, type=${printer.typePrinter}');
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

      // Use cached config directly (NO API CALL - instant!)
      _kotDocumentConfig = docConfigProvider.getCachedConfig("Kitchen Order") ??
                           docConfigProvider.getCachedConfig("kitchen_order");

      if (_kotDocumentConfig != null) {
        debugPrint("SUCCESS: KOT Document configuration loaded from cache");
      } else {
        debugPrint("WARNING: KOT Document config not found in cache");
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
      debugPrint("Fetching KOT document configurations from API with token...");
      await docConfigProvider.fetchDocumentConfigurations(
          accessToken: accessToken);

      _kotDocumentConfig = docConfigProvider.getDocumentConfig("Kitchen Order");

      if (_kotDocumentConfig != null) {
        debugPrint("SUCCESS: KOT Document configuration loaded from API");
      } else {
        debugPrint(
            "ERROR: KOT Document configuration still null after API fetch");
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

  Future<void> _handlePrinting() async {
    if (_kotDocumentConfig == null) {
      debugPrint("ERROR: KOT document configuration not loaded yet.");
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
      await _printThermalKot();
    } else {
      await _generateAndPrintPDF();
    }
  }

  Future<void> _printThermalKot() async {
    try {
      final kotPrinter = KotThermalPrinter(context);

      // Ensure time is in 12-hour format
      String formattedTime = DateHelper.formatISODateToIST(widget.orderTime);

      await kotPrinter.printKot(
        selectedPrinter: selectedPrinter!,
        orderNumber: widget.orderNumber,
        tokenNumber: widget.tokenNumber,
        tableName: widget.tableName,
        showTableLabel: widget.showTableLabel,
        orderTime: formattedTime,
        items: widget.items,
        comment: widget.comment,
        selectedPaperSize: selectedPaperSize,
        kotDocumentConfig: _kotDocumentConfig,
      );

      if (mounted) {

        showScaffold(
          context: context,
          message: "KOT printed successfully!",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Failed to print KOT: ${e.toString()}",
        );
      }
    }
  }

  Future<void> _generateAndPrintPDF() async {
    try {
      final kotStandardPrinter = KotStandardPrinter(context);

      // Ensure time is in 12-hour format
      String formattedTime = DateHelper.formatISODateToIST(widget.orderTime);

      await kotStandardPrinter.generateAndPrintKotPDF(
        orderNumber: widget.orderNumber,
        tokenNumber: widget.tokenNumber,
        tableName: widget.tableName,
        showTableLabel: widget.showTableLabel,
        orderTime: formattedTime,
        items: widget.items,
        comment: widget.comment,
        selectedPaperSize: selectedPaperSize,
        kotDocumentConfig: _kotDocumentConfig,
      );

      if (mounted) {

        showScaffold(
          context: context,
          message: "KOT PDF generated successfully!",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Failed to generate KOT PDF: ${e.toString()}",
        );
      }
    }
  }

  Future<void> _loadDefaultPaperSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try to load KOT specific paper size first
      String? paperSize = prefs.getString('kot_paper_size');

      // Fallback to default paper size if KOT paper size is not set
      if (paperSize == null) {
        paperSize = prefs.getString('default_paper_size');
      }

      if (paperSize != null) {
        setState(() {
          if (paperSize == 'Thermal') {
            selectedPaperSize = '80mm';
            _saveDefaultPaperSize('80mm');
          } else {
            selectedPaperSize = paperSize!;
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
    // Save to 'kot_paper_size' instead of 'default_paper_size'
    await prefs.setString('kot_paper_size', paperSize);

    setState(() {
      selectedPaperSize = paperSize;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            if (_kotDocumentConfig == null)
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
                if (selectedPrinter == null) {
                  showScaffoldError(
                    context: context,
                    message: "Please select a printer first",
                  );
                  return;
                }
                if (_kotDocumentConfig == null) {
                  showScaffoldError(
                    context: context,
                    message:
                        "Document configuration not loaded. Please wait or try again.",
                  );
                  return;
                }
                _handlePrinting();
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text(
                'Print KOT',
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
