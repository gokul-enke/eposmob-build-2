import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'customer_voucher_print_thermal.dart';
import 'customer_voucher_print_standard.dart';

class CustomerVoucherPrintPage extends StatefulWidget {
  final CustomerVoucher voucher;
  final bool returnToPreviousRoute;

  const CustomerVoucherPrintPage({
    super.key,
    required this.voucher,
    this.returnToPreviousRoute = false,
  });

  @override
  State<CustomerVoucherPrintPage> createState() =>
      _CustomerVoucherPrintPageState();
}

class _CustomerVoucherPrintPageState extends State<CustomerVoucherPrintPage> {
  var printerManager = PrinterManager.instance;
  List<BluetoothPrinter> devices = [];
  BluetoothPrinter? selectedPrinter;
  String selectedPaperSize = '80mm';
  bool _isScanning = false;
  StreamSubscription? _subscription;
  bool _isLoading = true;
  DocumentConfig? _voucherDocumentConfig;

  // Color scheme - matching print.dart
  static const Color primaryColor = Color(0XFF3C92F5);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFF2C3E50);
  static const Color textSecondaryColor = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDefaultPaperSize();
      await _loadDocumentConfig();
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
    debugPrint('[CustomerVoucherPrintPage] _checkPermissions() called');
    if (await _requestPermissions()) {
      debugPrint('[CustomerVoucherPrintPage] Permissions granted. Proceeding to scan.');
      _scan();
    } else {
      debugPrint('[CustomerVoucherPrintPage] Permissions NOT granted. Showing dialog.');
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    debugPrint(
        '[CustomerVoucherPrintPage] _requestPermissions() platform(os)=${Platform.operatingSystem} theme=${Theme.of(context).platform}');
    if (Theme.of(context).platform == TargetPlatform.android) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      statuses.forEach((perm, status) {
        debugPrint(
            '[CustomerVoucherPrintPage] Permission ${perm.toString()} => ${status.toString()}');
      });

      final granted = statuses.values.every((status) => status.isGranted);
      debugPrint('[CustomerVoucherPrintPage] All permissions granted: $granted');
      return granted;
    }
    debugPrint(
        '[CustomerVoucherPrintPage] Non-Android platform; skipping runtime permission request.');
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
          '[CustomerVoucherPrintPage] _scan() requested but a scan is already in progress. Ignoring.');
      return;
    }
    debugPrint(
        '[CustomerVoucherPrintPage] Starting scan... platform=${Platform.operatingSystem}');
    await _subscription?.cancel();
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Bluetooth discovery only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('[CustomerVoucherPrintPage] Beginning Bluetooth discovery (isBle=false)');
        _subscription = printerManager
            .discovery(type: PrinterType.bluetooth, isBle: false)
            .listen((device) {
          debugPrint(
              '[CustomerVoucherPrintPage] BT device found: name=${device.name}, address=${device.address}');
          final printer = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            typePrinter: PrinterType.bluetooth,
          );
          if (mounted) {
            setState(() {
              devices.add(printer);
            });
          }
        }, onError: (err) {
          debugPrint('[CustomerVoucherPrintPage] Bluetooth discovery error: $err');
        }, onDone: () {
          final btCount = devices
              .where((p) => p.typePrinter == PrinterType.bluetooth)
              .length;
          debugPrint(
              '[CustomerVoucherPrintPage] Bluetooth discovery done. Total BT devices: $btCount');
        }, cancelOnError: false);
      } else {
        debugPrint(
            '[CustomerVoucherPrintPage] Skipping Bluetooth discovery on desktop platform (${Platform.operatingSystem}).');
      }

      debugPrint('[CustomerVoucherPrintPage] Beginning USB discovery');
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        debugPrint(
            '[CustomerVoucherPrintPage] USB device found: name=${device.name}, vendorId=${device.vendorId}, productId=${device.productId}');
        final printer = BluetoothPrinter(
          deviceName: device.name,
          vendorId: device.vendorId,
          productId: device.productId,
          typePrinter: PrinterType.usb,
        );
        if (mounted) {
          setState(() {
            devices.add(printer);
          });
        }
      });
      debugPrint(
          '[CustomerVoucherPrintPage] USB discovery completed. Total devices now: ${devices.length}');
    } catch (e, st) {
      debugPrint('[CustomerVoucherPrintPage] Error during scanning: $e');
      debugPrint('[CustomerVoucherPrintPage] Stacktrace: $st');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
      debugPrint('[CustomerVoucherPrintPage] Scan finished. devices.length=${devices.length}');
    }
  }

  Future<void> _loadDefaultPrinter() async {
    debugPrint(
        '[CustomerVoucherPrintPage] _loadDefaultPrinter() reading from SharedPreferences');
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
      });
      debugPrint(
          '[CustomerVoucherPrintPage] Default printer loaded: name=${selectedPrinter?.deviceName}, address=${selectedPrinter?.address}, type=${selectedPrinter?.typePrinter}');

      // Load document configuration and auto-print
      if (selectedPrinter != null && _voucherDocumentConfig != null) {
        _handlePrint();
      }
    } else {
      debugPrint('[CustomerVoucherPrintPage] No default printer found in SharedPreferences');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocumentConfig() async {
    try {
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      debugPrint('[CustomerVoucherPrintPage] Loading document configuration...');
      
      _voucherDocumentConfig = docConfigProvider.getDocumentConfig('Voucher');
      
      if (_voucherDocumentConfig != null) {
        debugPrint('[CustomerVoucherPrintPage] Document configuration loaded');
        
        // Auto-print if printer is already loaded
        if (selectedPrinter != null) {
          _handlePrint();
        }
      } else {
        debugPrint('[CustomerVoucherPrintPage] Document configuration not found, fetching from API...');
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null) {
          await Provider.of<DocumentConfigProvider>(context, listen: false)
              .fetchDocumentConfigurations(accessToken: accessToken);
          _voucherDocumentConfig = docConfigProvider.getDocumentConfig('Voucher');
          
          if (_voucherDocumentConfig != null && selectedPrinter != null) {
            _handlePrint();
          }
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[CustomerVoucherPrintPage] Error loading document config: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDefaultPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPaperSize = prefs.getString('default_paper_size');

    if (savedPaperSize != null) {
      setState(() {
        selectedPaperSize = savedPaperSize;
      });
    }
  }

  Future<void> _saveDefaultPrinter() async {
    if (selectedPrinter != null) {
      final prefs = await SharedPreferences.getInstance();
      final printerJson = json.encode({
        'deviceName': selectedPrinter!.deviceName,
        'address': selectedPrinter!.address,
        'typePrinter': selectedPrinter!.typePrinter.toString(),
        'vendorId': selectedPrinter!.vendorId,
        'productId': selectedPrinter!.productId,
      });
      await prefs.setString('default_printer', printerJson);
    }
  }

  Future<void> _saveDefaultPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_paper_size', selectedPaperSize);
  }

  Future<void> _handlePrint() async {
    await _saveDefaultPrinter();
    await _saveDefaultPaperSize();

    // Load document configuration
    final docConfigProvider =
        Provider.of<DocumentConfigProvider>(context, listen: false);
    final voucherDocConfig =
        await docConfigProvider.getDocumentConfig('Voucher');

    if (!mounted) return;

    if (voucherDocConfig == null) {
      showScaffoldError(
        context: context,
        message: 'Failed to load voucher document configuration',
      );
      return;
    }

    debugPrint("===== HANDLE CUSTOMER VOUCHER PRINTING =====");
    debugPrint("Selected Paper Size: $selectedPaperSize");
    debugPrint("✅ Document configuration is available");

    // Route to appropriate printer
    if (selectedPaperSize == '80mm' || selectedPaperSize == '58mm') {
      debugPrint("Routing to thermal printer...");
      if (!mounted) return;
      await CustomerVoucherThermalPrinter(context).printCustomerVoucher(
        selectedPrinter: selectedPrinter,
        voucher: widget.voucher,
        selectedPaperSize: selectedPaperSize,
        voucherDocumentConfig: voucherDocConfig,
        customerCareNumber: '',
        customerCareEmail: '',
      );
      if (mounted && widget.returnToPreviousRoute) {
        Navigator.pop(context);
      }
    } else {
      debugPrint("Routing to PDF printer...");
      if (!mounted) return;
      await CustomerVoucherStandardPrinter(context)
          .generateAndPrintCustomerVoucherPDF(
        selectedPrinter: selectedPrinter,
        voucher: widget.voucher,
        selectedPaperSize: selectedPaperSize,
        voucherDocumentConfig: voucherDocConfig,
        customerCareNumber: '',
        customerCareEmail: '',
      );
      if (mounted && widget.returnToPreviousRoute) {
        Navigator.pop(context);
      }
    }

    debugPrint("===== END HANDLE CUSTOMER VOUCHER PRINTING =====");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Print Customer Voucher',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
          backgroundColor: primaryColor,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading printer and configuration...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Print Customer Voucher',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['80mm', '58mm', 'A5', 'A4']
                          .map((size) => ChoiceChip(
                                label: Text(size),
                                selected: selectedPaperSize == size,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedPaperSize = size;
                                      _saveDefaultPaperSize();
                                    });
                                  }
                                },
                              ))
                          .toList(),
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
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scan,
                            icon: _isScanning
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(_isScanning ? 'Scanning...' : 'Scan'),
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
                                printer.address ?? 'No address',
                                style: const TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedPrinter = printer;
                                });
                                _saveDefaultPrinter();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _scan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isScanning ? 'Scanning...' : 'Scan Printers'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: selectedPrinter == null ? null : _handlePrint,
              icon: const Icon(Icons.print),
              label: const Text('Print Voucher'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
