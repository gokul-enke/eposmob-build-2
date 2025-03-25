import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const Color primaryColor = Color(0XFF3C92F5);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFF2C3E50);
  static const Color textSecondaryColor = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      Provider.of<PaymentGatewaysProvider>(context, listen: false)
          .fetchPaymentGateways(accessToken: accessToken!);
      _loadDefaultPrinter();
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

      // If we have a default printer, automatically print
      if (selectedPrinter != null) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        final appSettings = appSettingsProvider.appSettings;
        printReceipt(
            appSettings!.customerCarePhone, appSettings.customerCareEmail);
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

  Future<void> printReceipt(
      String customerCareNumber, String customerCareEmail) async {
    if (selectedPrinter == null) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "No Printer Selected",
        );
      }
      return;
    }

    try {
      // Connect to the printer
      await _connectToPrinter();

      // Generate receipt
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Title
      // bytes += _buildTitle(generator, 'EPOS Invoice');

      //Header
      bytes += _buildHeader(generator, '${widget.storeName}',
          customerCareNumber, customerCareEmail);

      // Date and Order Number
      // bytes += _buildOrderDetails(generator);

      // Store Name
      // bytes += _buildStoreName(generator, widget.storeName.toString());

      // Item Table Header
      bytes += _buildTableHeader(generator);

      // Cart Items
      bytes += _buildCartItems(generator, widget.cartItems);

      // Total Amount
      bytes += _buildTotalAmount(generator);

      // Payment Details
      bytes += _buildPaymentDetails(generator);

      // Tax Details
      // bytes += _buildTaxDetails(generator);

      // Tax Details
      // bytes += _buildPointsDetails(generator);

      // Tax Details
      // bytes += _buildServiceDetails(generator);

      // Customer Care Details
      // bytes += _buildCustomerCareDetails(
      //     generator, customerCareNumber, customerCareEmail);

      // Thank You Message
      bytes += _buildThankYouMessage(generator);

      bytes += _buildQRCode(generator, customerCareNumber);

      // Cut the receipt
      bytes += generator.cut();

      // Print receipt
      await printerManager.send(
          type: selectedPrinter!.typePrinter, bytes: bytes);

      if (mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e) {
      debugPrint(e.toString());
      // if (mounted) {
      //   showScaffoldError(context: context, message: 'Error: ${e.toString()}');
      // }
    } finally {
      await _disconnectPrinter();
    }
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

  List<int> _buildHeader(Generator generator, String title,
      String customerCareNumber, String customerCareEmail) {
    List<int> bytes = [];

    // // Store Details
    // bytes += generator.text(title,
    //     styles: const PosStyles(
    //         align: PosAlign.center, bold: true, height: PosTextSize.size2));

    // bytes += generator.row([
    //   PosColumn(
    //     text: '', // Empty column on the left
    //     width: 3,
    //   ),
    //   PosColumn(
    //     text: title, // The main centered text
    //     width: 6,
    //     styles: const PosStyles(
    //         align: PosAlign.center, bold: true, height: PosTextSize.size2),
    //   ),
    //   PosColumn(
    //     text: '', // Empty column on the right
    //     width: 3,
    //   ),
    // ]);

    bytes += generator.row([
      PosColumn(
        text: title, // The main centered text
        width: 12,
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2),
      ),
    ]);

    // bytes += generator.text('Manjeri,Malappuram',
    //     styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('TEL: $customerCareNumber',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Email: $customerCareEmail',
        styles: const PosStyles(align: PosAlign.center));
    // bytes += generator.text('The Goods and Service Tax Rule 2017',
    //     styles: const PosStyles(align: PosAlign.center));
    // bytes += generator.text('GSTIN No: 32AAT000004G1ZH',
    //     styles: const PosStyles(align: PosAlign.center));
    // bytes += generator.text('FSSAI: 113250100000078',
    //     styles: const PosStyles(align: PosAlign.center));

    // Invoice Title
    bytes += generator.text('INVOICE ${widget.orderNumber}',
        styles: const PosStyles(align: PosAlign.center, bold: true));

    // Date and Time
    // bytes += generator.text(
    //     'Date: ${DateHelper.formatISODate(widget.orderDate)}  Order#: ${widget.orderNumber}',
    //     styles: const PosStyles(align: PosAlign.center));
    // bytes += generator.text(
    //     'Time: ${DateHelper.formatISODateToIST(widget.orderDate)} Store Name: ${widget.storeName}',
    //     styles: const PosStyles(align: PosAlign.center));

    // Separator
    // bytes += generator.text("================================");
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

    return bytes;
  }

  List<int> _buildTitle(Generator generator, String title) {
    return generator.text(title,
            styles: const PosStyles(
                align: PosAlign.center,
                bold: true,
                height: PosTextSize.size2)) +
        // generator.text("================================");
        generator.hr();
  }

  List<int> _buildOrderDetails(Generator generator) {
    return generator.text('Date: ${widget.orderDate}',
            styles: const PosStyles(align: PosAlign.left)) +
        generator.text('Order#: ${widget.orderNumber}',
            styles: const PosStyles(align: PosAlign.left)) +
        // generator.text("================================");
        generator.hr();
  }

  List<int> _buildStoreName(Generator generator, String storeName) {
    return generator.text('Store Name: $storeName',
            styles: const PosStyles(align: PosAlign.left)) +
        generator.hr();
    // generator.text("================================");
  }

  List<int> _buildTableHeader(Generator generator) {
    return generator.row([
          // PosColumn(text: 'Sl#', width: 1),
          PosColumn(text: 'PARTICULARS', width: 4),
          PosColumn(
              text: 'MRP',
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: 'QTY',
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: 'RATE',
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
          PosColumn(
              text: 'TOTAL',
              width: 2,
              styles: const PosStyles(align: PosAlign.right)),
        ]) +
        generator.hr();
    // generator.text("================================");
  }

  List<int> _buildCartItems(Generator generator, List<dynamic> cartItems) {
    List<int> bytes = [];
    
    debugPrint("Building cart items, count: ${cartItems.length}");
    debugPrint("Is from local storage: ${widget.isFromLocalStorage}");
    
    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];
      
      // Debug the item structure
      if (i == 0) {
        debugPrint("First item type: ${item.runtimeType}");
        if (widget.isFromLocalStorage) {
          debugPrint("Item keys: ${item.keys.toList()}");
        }
      }
      
      // Handle different models based on data source
      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';
      
      // Adapt the model based on whether it's from local storage or current cart
      if (widget.isFromLocalStorage) {
        // Handle saved order item format (Map format)
        productName = item['productName'] ?? '';
        mrp = item['mrp'] ?? '0.00';
        quantity = item['quantity'] ?? '0';
        unitPrice = item['unitPrice'] ?? '0.00';
        totalPrice = item['totalPrice'] ?? '0.00';
        
        debugPrint("From storage - Product: $productName, Qty: $quantity, Price: $unitPrice");
      } else {
        // Handle current cart item format (Object format)
        productName = item.productName ?? '';
        mrp = item.mrp ?? '0.00';
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = item.unitPrice?.toString() ?? '0.00';
        totalPrice = item.totalPrice?.toString() ?? '0.00';
      }
      
      bytes += generator.row([
        PosColumn(text: productName, width: 4),
        PosColumn(
            text: mrp,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: quantity,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: unitPrice,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: totalPrice,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    return bytes + generator.hr();
  }

  List<int> _buildTotalAmount(Generator generator) {
    List<int> bytes = [];

    bytes += generator.row([
      // PosColumn(text: 'Sl#', width: 1),
      PosColumn(text: 'DISCOUNT 0.00', width: 6),
      // PosColumn(
      //     text: 'MRP',
      //     width: 2,
      //     styles: const PosStyles(align: PosAlign.right)),
      PosColumn(
          text: widget.cartItems.length.toString(),
          width: 2,
          styles: const PosStyles(align: PosAlign.right)),
      PosColumn(
          text: '', width: 2, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(
          text: widget.formattedTotal,
          width: 2,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
          text: 'Net Amount',
          width: 6,
          styles: const PosStyles(
              align: PosAlign.left, bold: true, height: PosTextSize.size1)),
      PosColumn(
          text: widget.formattedTotal,
          width: 6,
          styles: const PosStyles(
              align: PosAlign.right, bold: true, height: PosTextSize.size1)),
    ]);

    bytes += generator.hr();

    List<Map<String, String>> items = [
      // {'label': 'Net Amount', 'value': widget.formattedTotal},
      {
        'label': 'Items ${widget.cartItems.length}',
        'value':
            "MRP TOTAL ${(double.parse(widget.savedTotal!) + double.parse(widget.formattedTotal))}"
      },
      {'label': 'You Save', 'value': widget.savedTotal ?? "0.00"},
      // {'label': 'E&OE Discount', 'value': '0.00'},
      // {'label': 'Sales Return', 'value': '0.00'},
      // {'label': 'RoundOff', 'value': '0.00'},
      // {'label': 'Invoice Total:', 'value': widget.formattedTotal},
    ];

    for (var item in items) {
      bytes += generator.row([
        PosColumn(
            text: item['label']!,
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: item['value']!,
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    // Amount in Words
    // bytes += generator.text(
    //     'Two Thousand Nine Hundred Fifty Four INDIAN RUPEES Only.',
    //     styles: const PosStyles(align: PosAlign.left));

    // Separator
    // bytes += generator.text("================================");
    generator.hr();
    return bytes;
  }

  List<int> _buildPaymentDetails(Generator generator) {
    List<int> bytes = [];

    // Payment Header
    // bytes += generator.text('CASH     | CARD     | COUPON   | CHANGE',
    //     styles: const PosStyles(align: PosAlign.center));

    // // Payment Values (dummy data)
    // bytes += generator.text('3000.00  | 0.00     | 0.00     | 46.00',
    //     styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // Savings Message
    // bytes += generator.text('You Have Saved ${widget.savedTotal ?? "0.00"}',
    //     styles: const PosStyles(bold: true, align: PosAlign.center));
    // bytes += generator.text('0.00',
    //     styles: const PosStyles(bold: true, align: PosAlign.center));

    // Separator
    // bytes += generator.hr();

    return bytes;
  }

  List<int> _buildTaxDetails(Generator generator) {
    List<int> bytes = [];

    // Tax Header
    bytes += generator.text(
        'GST       | TaxableAmt | SGST     | CGST     | TotalGST',
        styles: const PosStyles(bold: true, align: PosAlign.center));
    bytes += generator.hr();

    // Tax Details (dummy data)
    bytes += generator.text(
        '0%       | 207.00     | 0.00     | 0.00     | 0.00',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(
        '5%       | 947.62     | 23.69    | 23.69    | 23.69',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(
        '12%      | 936.79     | 28.61    | 28.61    | 57.21',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(
        '18%      | 1032.18    | 92.90    | 92.90    | 185.80',
        styles: const PosStyles(align: PosAlign.center));

    // Total Taxable Amount
    bytes += generator.hr();
    bytes += generator.text(
        'Total    | 2663.59    | 145.20   | 145.20   | 290.39',
        styles: const PosStyles(bold: true, align: PosAlign.center));

    // MRP Total
    bytes += generator.text('MRP Total: 5495.00',
        styles: const PosStyles(bold: true, align: PosAlign.left));

    // Separator
    bytes += generator.hr();

    return bytes;
  }

  List<int> _buildPointsDetails(Generator generator) {
    List<int> bytes = [];

    // Points Header
    bytes += generator.text('NewPoint | Redeem | Balance | CardBalance',
        styles: const PosStyles(bold: true, align: PosAlign.center));

    bytes += generator.hr();

    return bytes;
  }

  List<int> _buildServiceDetails(Generator generator) {
    List<int> bytes = [];

    // Points Values (dummy data)
    bytes += generator.text('0.00     | 0.00   | 0.00    | 0.00',
        styles: const PosStyles(align: PosAlign.center));

    // Service Details Header
    bytes += generator.text(
        'Served by | Total Item | Print Date & Time | Counter | DD',
        styles: const PosStyles(bold: true, align: PosAlign.center));

    bytes += generator.hr();

    // Service Details Values (dummy data)
    bytes += generator.text(
        'adhi      | 27.00     | 21-02-2025 19:39:36 | POS5',
        styles: const PosStyles(align: PosAlign.center));

    // Separator
    bytes += generator.hr();

    return bytes;
  }

  List<int> _buildCustomerCareDetails(
      Generator generator, String customerCareNumber, String email) {
    return generator.text('Customer Care: $customerCareNumber',
            styles: const PosStyles(align: PosAlign.center)) +
        generator.text('Email: $email',
            styles: const PosStyles(align: PosAlign.center)) +
        // generator.text("================================");
        generator.hr();
  }

  List<int> _buildThankYouMessage(Generator generator) {
    List<int> bytes = [];

    // Terms & Conditions Header
    // bytes += generator.text('Terms & Conditions',
    //     styles: const PosStyles(bold: true, align: PosAlign.center));

    // Terms & Conditions Text
    // bytes += generator.text(
    //     '* No product will be replaced/returned after 7 days from the date of purchase.',
    //     styles: const PosStyles(align: PosAlign.left));
    // bytes += generator.text('* No product will be replaced without bill.',
    //     styles: const PosStyles(align: PosAlign.left));

    // Thank You Message
    bytes += generator.text('Thank You... Visit Again ',
        styles: const PosStyles(bold: true, align: PosAlign.center));

    // Separator
    bytes += generator.hr();

    return bytes;
  }

  List<int> _buildQRCode(Generator generator, String customerCareNumber) {
    final paymentGatewaysProvider =
        Provider.of<PaymentGatewaysProvider>(context, listen: false);
    final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
        .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY");
    List<int> bytes = [];

    // Add space before QR code
    bytes += generator.emptyLines(1);

    // Add QR Code - You can customize the data to whatever you need
    // For example, a URL to your store website or a customer feedback form
    bytes += generator.qrcode(
      'upi://pay?pa=${manualPaymentGateway.link}&am=${widget.formattedTotal}&tn=${widget.orderNumber}&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1',
      size: QRSize.Size4,
      align: PosAlign.center,
    );

    // Add space after QR code
    bytes += generator.emptyLines(1);

    // Add a label for the QR code
    bytes += generator.text('Scan this QR code to Pay',
        styles: const PosStyles(align: PosAlign.center));

    // Separator
    bytes += generator.hr();

    return bytes;
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
