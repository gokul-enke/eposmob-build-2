import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

class PrintPage extends StatefulWidget {
  final List<dynamic> cartItems;
  final String? storeName;
  final String formattedTotal;
  final String orderDate;
  final String orderNumber;
  const PrintPage({
    Key? key,
    required this.cartItems,
    required this.formattedTotal,
    this.storeName,
    required this.orderDate,
    required this.orderNumber,
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

  static const Color primaryColor = Color(0XFF3C92F5);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFF2C3E50);
  static const Color textSecondaryColor = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
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
        debugPrint('Found Bluetooth device: ${device.name}');
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
        debugPrint('Found USB device: ${device.name}');
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

  void selectPrinter(BluetoothPrinter printer) {
    debugPrint('Selecting printer:');
    debugPrint('Device Name: ${printer.deviceName}');
    debugPrint('Address: ${printer.address}');
    debugPrint('Type: ${printer.typePrinter}');
    debugPrint('VendorId: ${printer.vendorId}');
    debugPrint('ProductId: ${printer.productId}');

    setState(() {
      selectedPrinter = printer;
    });

    if (mounted) {
      showScaffold(
        context: context,
        message: "${printer.deviceName.toString()} Printer Selected",
      );
    }
  }

  Future<void> printReceipt(
      String customerCareNumber, String customerCareEmail) async {
    debugPrint('Starting printReceipt function');
    debugPrint('Selected Printer: ${selectedPrinter?.deviceName}');
    debugPrint('Selected Printer Address: ${selectedPrinter?.address}');
    debugPrint('Printer Type: ${selectedPrinter?.typePrinter}');
    debugPrint('VendorId: ${selectedPrinter?.vendorId}');
    debugPrint('ProductId: ${selectedPrinter?.productId}');
    debugPrint('Customer Care Number: $customerCareNumber');
    debugPrint('Customer Care Email: $customerCareEmail');

    if (selectedPrinter == null) {
      debugPrint('Error: No printer selected');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "No Printer Selected",
        );
      }
      return;
    }

    try {
      debugPrint('Attempting to connect to printer...');
      // Connect to the printer based on type
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

      debugPrint('Successfully connected to printer');

      // Generate receipt
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Title
      String title = 'EPOS Invoice';
      bytes += generator.text(title,
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2));
      debugPrint('Printing: $title');

      // bytes += generator.feed(1);
      bytes += generator.text("================================");

      // Date and Order number
      String orderDateText = 'Date: ${widget.orderDate}';
      String orderNumberText = 'Order#: ${widget.orderNumber}';
      bytes += generator.text(orderDateText,
          styles: const PosStyles(align: PosAlign.left));
      debugPrint('Printing: $orderDateText');

      bytes += generator.text(orderNumberText,
          styles: const PosStyles(align: PosAlign.left));
      debugPrint('Printing: $orderNumberText');

      // Store Name
      String storeNameText = 'Store Name: ${widget.storeName}';
      bytes += generator.text(storeNameText,
          styles: const PosStyles(align: PosAlign.left));
      debugPrint('Printing: $storeNameText');

      bytes += generator.text("================================");

      // bytes += generator.feed(1);

// Table header
      bytes += generator.row([
        PosColumn(text: 'Sl#', width: 1),
        PosColumn(text: 'Item', width: 5), // Wider for wrapping
        PosColumn(
            text: 'Qty',
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: 'Price',
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: 'Amount',
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.text("================================");

      for (var i = 0; i < widget.cartItems.length; i++) {
        var item = widget.cartItems[i];

        bytes += generator.row([
          PosColumn(text: (i + 1).toString(), width: 1),
          PosColumn(
            text: item.productName ?? '',
            width: 5,
          ),
          PosColumn(
              text: item.quantity.toString(),
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: item.unitPrice.toString(),
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: item.totalPrice.toString(),
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.text("================================");

      // Add total
      String totalText = 'Total: ${widget.formattedTotal}';
      debugPrint('Printing: $totalText');

      bytes += generator.row([
        PosColumn(
            text: 'Total:', width: 9, styles: const PosStyles(bold: true)),
        PosColumn(
            text: widget.formattedTotal,
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.text("================================");

      // bytes += generator.feed(1);

      // Customer Care Details
      String customerCareText = 'Customer Care: $customerCareNumber';
      String emailText = 'Email: $customerCareEmail';
      bytes += generator.text(customerCareText,
          styles: const PosStyles(align: PosAlign.center));
      debugPrint('Printing: $customerCareText');

      bytes += generator.text(emailText,
          styles: const PosStyles(align: PosAlign.center));
      debugPrint('Printing: $emailText');

      bytes += generator.text("================================");
      bytes += generator.text("Thankyou visit again !!!",
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.text("================================");

      // bytes += generator.feed(2);
      bytes += generator.cut();

      // Print receipt
      debugPrint('Sending print job to printer...');
      await printerManager.send(
          type: selectedPrinter!.typePrinter, bytes: bytes);
      debugPrint('Print job sent successfully');
      if (mounted) {
        showScaffold(
          context: context,
          message: "Print job sent successfully",
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error in printReceipt: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      debugPrint('Disconnecting from printer...');
      try {
        await printerManager.disconnect(type: selectedPrinter!.typePrinter);
        debugPrint('Successfully disconnected from printer');
      } catch (e) {
        debugPrint('Error disconnecting from printer: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

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
                  : printReceipt(appSettings!.customerCarePhone,
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
