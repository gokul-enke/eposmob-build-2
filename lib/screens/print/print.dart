import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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
  String customerCareNumber = "Number";
  String customerCareEmail = "Email";

  @override
  void initState() {
    super.initState();
    fetchCustomerCareInfo();
    _checkPermissions();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> fetchCustomerCareInfo() async {
    final response = await http.get(Uri.parse(
        "https://epos.enke.in/api/company/get-company-props?cart_id=1"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        customerCareNumber = data['customer_care']
            ['number']; // Adjust these keys as per API response
        customerCareEmail = data['customer_care']
            ['email']; // Adjust these keys as per API response
      });
    } else {
      throw Exception('Failed to load customer care information');
    }
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
    return true; // For iOS, permissions are handled in Info.plist
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

      // Scan for USB printers
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        final printer = BluetoothPrinter(
          deviceName: device.name,
          address: device.address,
          vendorId: device.vendorId,
          productId: device.productId,
          typePrinter: PrinterType.usb,
        );
        setState(() {
          devices.add(printer);
        });
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void selectPrinter(BluetoothPrinter printer) {
    setState(() {
      selectedPrinter = printer;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${printer.deviceName.toString()} Printer Selected')),
    );
  }

  Future<void> printReceipt() async {
    if (selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Printer Selected')),
      );
      return;
    }

    try {
      // Connect to the printer
      await printerManager.connect(
        type: selectedPrinter!.typePrinter,
        model: selectedPrinter!.typePrinter == PrinterType.bluetooth
            ? BluetoothPrinterInput(
                name: selectedPrinter!.deviceName!,
                address: selectedPrinter!.address!,
                isBle: false,
              )
            : TcpPrinterInput(ipAddress: selectedPrinter!.address!),
      );

      // Generate receipt
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Title
      bytes += generator.text('EPOS Invoice',
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.feed(1);

      // Date and Order number
      bytes += generator.text('Date: ${widget.orderDate}',
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.text('Order#: ${widget.orderNumber}',
          styles: const PosStyles(align: PosAlign.left));

      // Store Name (You might want to make this configurable)
      bytes += generator.text('Store Name: ${widget.storeName}',
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.feed(1);

      // Table header
      bytes += generator.row([
        PosColumn(text: 'Sl#', width: 1),
        PosColumn(text: 'Item', width: 4),
        PosColumn(text: 'Qty', width: 2),
        PosColumn(text: 'Unit Price', width: 2),
        PosColumn(text: 'Price', width: 3),
      ]);
      bytes += generator.hr();

      // Add cart items
      for (var i = 0; i < widget.cartItems.length; i++) {
        var item = widget.cartItems[i];
        bytes += generator.row([
          PosColumn(text: (i + 1).toString(), width: 1),
          PosColumn(text: item.productName ?? '', width: 4),
          PosColumn(text: item.quantity.toString(), width: 2),
          PosColumn(text: item.unitPrice.toString(), width: 2),
          PosColumn(text: item.totalPrice.toString(), width: 3),
        ]);
      }

      bytes += generator.hr();

      // Add total
      bytes += generator.row([
        PosColumn(
            text: 'Total:', width: 9, styles: const PosStyles(bold: true)),
        PosColumn(
            text: widget.formattedTotal,
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      bytes += generator.feed(1);

      // Note
      bytes += generator.text('Note: This is a computer generated invoice',
          styles: const PosStyles(align: PosAlign.center));

      // Customer Care Details from API
      if (customerCareNumber != null && customerCareEmail != null) {
        bytes += generator.text('Customer Care: $customerCareNumber',
            styles: const PosStyles(align: PosAlign.center));
        bytes += generator.text('Email: $customerCareEmail',
            styles: const PosStyles(align: PosAlign.center));
      }

      // // Customer Care
      // bytes += generator.text('Customer Care: +91 9496410199',
      //     styles: const PosStyles(align: PosAlign.center));
      // bytes += generator.text('Email: customercare@eposenke.in',
      //     styles: const PosStyles(align: PosAlign.center));

      bytes += generator.feed(2);
      bytes += generator.cut();

      // Print receipt
      await printerManager.send(
          type: selectedPrinter!.typePrinter, bytes: bytes);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print job sent successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      // Disconnect from the printer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Print Disconnected')),
      );
      await printerManager.disconnect(type: selectedPrinter!.typePrinter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer List'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devices[index].deviceName ?? 'Unknown device'),
                  subtitle: Text(devices[index].address ?? ''),
                  trailing: ElevatedButton(
                    onPressed: () => selectPrinter(devices[index]),
                    child: Text(selectedPrinter == devices[index]
                        ? 'Selected'
                        : 'Select'),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: selectedPrinter == null ? null : printReceipt,
            child: const Text('Print Receipt'),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _checkPermissions,
        tooltip: 'Scan for printers',
        child: _isScanning
            ? const CircularProgressIndicator()
            : const Icon(Icons.refresh),
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

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
  });
}
