import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/screens/print/print_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

class BluetoothPrinter {
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  String typePrinter;
  bool isConnected;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.vendorId,
    this.productId,
    required this.typePrinter,
    this.isConnected = false,
  });
}

class PrinterSettings extends StatefulWidget {
  const PrinterSettings({super.key});

  @override
  State<PrinterSettings> createState() => _PrinterSettingsState();
}

class _PrinterSettingsState extends State<PrinterSettings> {
  BluetoothPrinter? selectedPrinter;
  bool isLoading = true;
  String selectedPaperSize = '80mm';
  String selectedFontStyle = 'Font A (Small & Sharp)';

  // Printer scanning variables
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  bool _isScanning = false;

  // List of available paper sizes
  final List<String> paperSizes = ['80mm', '58mm', 'A5', 'A4'];

  // List of available font styles
  final List<String> fontStyles = [
    'Font A (Small & Sharp)',
    'Font B (Default)',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
      _subscription = printerManager
          .discovery(type: PrinterType.bluetooth, isBle: false)
          .listen((device) {
        final printer = BluetoothPrinter(
          deviceName: device.name,
          address: device.address,
          typePrinter: PrinterType.bluetooth.toString(),
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
          typePrinter: PrinterType.usb.toString(),
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

  Future<void> _loadSettings() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson = prefs.getString('default_printer');
    final defaultPaperSize = prefs.getString('default_paper_size');
    final defaultFontStyle = prefs.getString('default_font_style');

    // Load paper size
    if (defaultPaperSize != null) {
      setState(() {
        // Migrate from 'Thermal' to '80mm'
        if (defaultPaperSize == 'Thermal') {
          selectedPaperSize = '80mm';
          // Update the stored preference
          _saveDefaultPaperSize('80mm');
        } else {
          selectedPaperSize = defaultPaperSize;
        }
      });
    } else {
      // Default to 80mm if no preference is set
      setState(() {
        selectedPaperSize = '80mm';
      });
      _saveDefaultPaperSize('80mm');
    }

    // Load font style
    if (defaultFontStyle != null) {
      setState(() {
        selectedFontStyle = defaultFontStyle;
      });
    } else {
      // Default to Font B if no preference is set
      setState(() {
        selectedFontStyle = 'Font A (Small & Sharp)';
      });
      _saveDefaultFontStyle('Font A (Small & Sharp)');
    }

    // Load default printer
    if (defaultPrinterJson != null) {
      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
      setState(() {
        selectedPrinter = BluetoothPrinter(
          deviceName: printerData['deviceName'],
          address: printerData['address'],
          vendorId: printerData['vendorId'],
          productId: printerData['productId'],
          typePrinter: printerData['typePrinter'],
        );
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> clearDefaultPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('default_printer');

      setState(() {
        selectedPrinter = null;
      });

      if (mounted) {
        showScaffold(
          context: context,
          message: "Default printer cleared successfully",
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error clearing default printer: ${e.toString()}",
        );
      }
    }
  }

  Future<void> clearLocalStorageAndLogout() async {
    try {
      // Show confirmation dialog
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Local Storage'),
          content: const Text(
            'This will clear all local data except login credentials and log you out. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Clear & Logout',
                style: TextStyle(color: ColorManager.kButtonRed),
              ),
            ),
          ],
        ),
      );

      if (shouldClear != true) return;

      final prefs = await SharedPreferences.getInstance();

      // Save login credentials before clearing
      final String? emailRemember = prefs.getString('emailRemember');
      final String? passwordRemember = prefs.getString('passwordRemember');
      final bool? rememberMe = prefs.getBool('remember_me');

      // Clear all SharedPreferences except login credentials
      await prefs.clear();

      // Restore login credentials if needed
      if (rememberMe == true) {
        await prefs.setBool('remember_me', true);
        if (emailRemember != null) {
          await prefs.setString('emailRemember', emailRemember);
        }
        if (passwordRemember != null) {
          await prefs.setString('passwordRemember', passwordRemember);
        }
      }

      // Clear Hive data
      await clearAllHiveData();

      // Log out - clear auth data from provider
      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.logout();

      if (mounted) {
        showScaffold(
          context: context,
          message: "Local storage cleared successfully",
        );

        // Navigate to login screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignInScreen()),
            (route) => false,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error clearing local storage: ${e.toString()}",
        );
      }
    }
  }

  Future<void> _saveDefaultPaperSize(String paperSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_paper_size', paperSize);

    if (mounted) {
      showScaffold(
        context: context,
        message: "Default paper size saved",
      );
    }
  }

  Future<void> _saveDefaultFontStyle(String fontStyle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_font_style', fontStyle);

    if (mounted) {
      showScaffold(
        context: context,
        message: "Default font style saved",
      );
    }
  }

  Future<void> _printSample() async {
    if (selectedPrinter == null) {
      showScaffoldError(
        context: context,
        message: "Please select a printer first",
      );
      return;
    }

    try {
      // Convert selected font style to PosFontType
      PosFontType fontType = selectedFontStyle.contains('Font A')
          ? PosFontType.fontA
          : PosFontType.fontB;

      // Create dummy cart items
      List<Map<String, dynamic>> dummyCartItems = [
        {
          'productName': 'Premium Coffee Beans (Arabica)',
          'mrp': '450.00',
          'quantity': '2',
          'unitPrice': '400.00',
          'totalPrice': '800.00'
        },
        {
          'productName': 'Organic Green Tea Leaves',
          'mrp': '250.00',
          'quantity': '1',
          'unitPrice': '225.00',
          'totalPrice': '225.00'
        },
        {
          'productName': 'Fresh Milk (Full Cream) 1L',
          'mrp': '65.00',
          'quantity': '3',
          'unitPrice': '60.00',
          'totalPrice': '180.00'
        },
        {
          'productName': 'Whole Wheat Bread',
          'mrp': '45.00',
          'quantity': '2',
          'unitPrice': '40.00',
          'totalPrice': '80.00'
        },
        {
          'productName': 'Premium Dark Chocolate Bar',
          'mrp': '120.00',
          'quantity': '1',
          'unitPrice': '110.00',
          'totalPrice': '110.00'
        },
      ];

      // Print sample with the selected font style
      await _printSampleReceipt(
        selectedPrinter!,
        dummyCartItems,
        fontType,
        '1395.00', // Total amount
        '55.00', // Saved amount
        DateTime.now().toIso8601String(),
        'SAMPLE-${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        showScaffold(
          context: context,
          message: "Sample receipt sent to printer",
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error printing sample: ${e.toString()}",
        );
      }
    }
  }

  Future<void> _printSampleReceipt(
    BluetoothPrinter printer,
    List<Map<String, dynamic>> cartItems,
    PosFontType fontType,
    String formattedTotal,
    String savedTotal,
    String orderDate,
    String orderNumber,
  ) async {
    var printerManager = PrinterManager.instance;

    try {
      // Connect to printer
      await _connectToPrinter(printer);

      // Generate receipt with all fields enabled (dummy document config)
      final profile = await CapabilityProfile.load();
      PaperSize paperSize =
          selectedPaperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80;
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // Text sizes based on font type
      PosTextSize textSizeTitle = PosTextSize.size4;
      PosTextSize textSizeBig = PosTextSize.size3;
      PosTextSize textSizeMedium = PosTextSize.size2;
      PosTextSize textSizeSmall = PosTextSize.size1;

      // Header
      bytes += generator.text('SAMPLE STORE',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeTitle));

      bytes += generator.text('Sample Receipt Test',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeMedium));

      bytes += generator.text('123 Sample Street, Demo City',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));

      bytes += generator.text('TEL: +1-234-567-8900',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));

      bytes += generator.text('Email: sample@store.com',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));

      bytes += generator.text('INVOICE',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeMedium));

      bytes += generator.text('INV No: $orderNumber',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeMedium));

      // Table header
      bytes += generator.row([
        PosColumn(
            text: 'SL#',
            width: 1,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: textSizeMedium)),
        PosColumn(
            text: 'PARTICULARS',
            width: 3,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: textSizeMedium)),
        PosColumn(
            text: 'MRP',
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeMedium)),
        PosColumn(
            text: 'QTY',
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeMedium)),
        PosColumn(
            text: 'RATE',
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeMedium)),
        PosColumn(
            text: 'TOTAL',
            width: 2,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeMedium)),
      ]);
      bytes += generator.hr();

      // Cart items
      for (var i = 0; i < cartItems.length; i++) {
        var item = cartItems[i];

        // Product name row
        bytes += generator.row([
          PosColumn(
              text: '${i + 1}',
              width: 1,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.left,
                  bold: true,
                  height: textSizeMedium)),
          PosColumn(
              text: item['productName'],
              width: 11,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.left,
                  bold: true,
                  height: textSizeMedium)),
        ]);

        // Price details row
        bytes += generator.row([
          PosColumn(
              text: '',
              width: 1,
              styles: PosStyles(fontType: fontType, align: PosAlign.left)),
          PosColumn(
              text: '',
              width: 3,
              styles: PosStyles(fontType: fontType, align: PosAlign.left)),
          PosColumn(
              text: item['mrp'],
              width: 2,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.right,
                  bold: false,
                  height: textSizeMedium)),
          PosColumn(
              text: item['quantity'],
              width: 2,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.right,
                  bold: false,
                  height: textSizeMedium)),
          PosColumn(
              text: item['unitPrice'],
              width: 2,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.right,
                  bold: false,
                  height: textSizeMedium)),
          PosColumn(
              text: item['totalPrice'],
              width: 2,
              styles: PosStyles(
                  fontType: fontType,
                  align: PosAlign.right,
                  bold: false,
                  height: textSizeMedium)),
        ]);
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.row([
        PosColumn(
            text: 'Items',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: textSizeSmall)),
        PosColumn(
            text: '${cartItems.length}',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeSmall)),
      ]);

      bytes += generator.row([
        PosColumn(
            text: 'Total Quantity',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: textSizeSmall)),
        PosColumn(
            text: '9',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeSmall)),
      ]);

      bytes += generator.row([
        PosColumn(
            text: 'Total MRP',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: textSizeSmall)),
        PosColumn(
            text: '1450.00',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeSmall)),
      ]);

      bytes += generator.row([
        PosColumn(
            text: 'You Saved',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: false,
                height: textSizeMedium)),
        PosColumn(
            text: savedTotal,
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeMedium)),
      ]);

      bytes += generator.row([
        PosColumn(
            text: 'Net Total',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: textSizeBig)),
        PosColumn(
            text: formattedTotal,
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeBig)),
      ]);

      bytes += generator.hr();

      // Amount in words
      bytes += generator.text(
          'One Thousand Three Hundred Ninety Five Rupees Only.',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));

      // Date and time
      bytes += generator.row([
        PosColumn(
            text:
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: textSizeSmall)),
        PosColumn(
            text:
                '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.right,
                bold: true,
                height: textSizeSmall)),
      ]);

      bytes += generator.hr();

      // Barcode
      try {
        List<String> code39Data =
            orderNumber.replaceAll(RegExp(r'[^A-Z0-9\-]'), '').split("");
        bytes += generator.barcode(
          Barcode.code39(code39Data),
          height: selectedPaperSize == '58mm' ? 20 : 30,
          width: 1,
          textPos: BarcodeText.none,
          align: PosAlign.center,
        );
      } catch (e) {
        bytes += generator.text(orderNumber,
            styles: PosStyles(
                fontType: fontType, align: PosAlign.center, bold: true));
      }

      // Terms and conditions
      bytes += generator.hr();
      bytes += generator.text('TERMS & CONDITIONS:',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: textSizeSmall));
      bytes += generator.text('1. All sales are final unless defective.',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
      bytes += generator.text('2. Returns accepted within 7 days with receipt.',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));
      bytes += generator.text(
          '3. Store credit issued for returns without receipt.',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: false,
              height: textSizeSmall));

      // Thank you message
      bytes += generator.hr();
      bytes += generator.text('Thank You for Shopping with Us!',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeMedium));

      bytes += generator.text('Visit Again Soon!',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: textSizeSmall));

      // Cut
      bytes += generator.cut();

      // Print
      PrinterType type = printer.typePrinter == PrinterType.usb.toString()
          ? PrinterType.usb
          : PrinterType.bluetooth;
      await printerManager.send(type: type, bytes: bytes);
    } finally {
      await _disconnectPrinter(printer);
    }
  }

  Future<void> _connectToPrinter(BluetoothPrinter selectedPrinter) async {
    if (selectedPrinter.typePrinter == PrinterType.usb.toString()) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: selectedPrinter.deviceName ?? 'Unknown',
          productId: selectedPrinter.productId,
          vendorId: selectedPrinter.vendorId,
        ),
      );
    } else if (selectedPrinter.typePrinter ==
        PrinterType.bluetooth.toString()) {
      if (selectedPrinter.address == null) {
        throw Exception('Bluetooth printer address is null');
      }
      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: selectedPrinter.deviceName ?? 'Unknown',
          address: selectedPrinter.address!,
          isBle: false,
        ),
      );
    }
  }

  Future<void> _disconnectPrinter(BluetoothPrinter selectedPrinter) async {
    try {
      PrinterType type =
          selectedPrinter.typePrinter == PrinterType.usb.toString()
              ? PrinterType.usb
              : PrinterType.bluetooth;
      await printerManager.disconnect(type: type);
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
    }
  }

  Future<void> clearAllHiveData() async {
    try {
      // Close all open boxes
      if (Hive.isBoxOpen('products')) {
        await Hive.box<HiveProduct>('products').close();
      }
      if (Hive.isBoxOpen('cart_items')) {
        await Hive.box<HiveLocalCartItem>('cart_items').close();
      }
      if (Hive.isBoxOpen('saved_orders')) {
        await Hive.box<HiveSavedOrder>('saved_orders').close();
      }
      if (Hive.isBoxOpen('confirmed_orders')) {
        await Hive.box<HiveSavedOrder>('confirmed_orders').close();
      }

      // Delete all Hive files
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
      }

      if (mounted) {
        showScaffold(
          context: context,
          message: "All Hive data cleared successfully",
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error clearing Hive data: ${e.toString()}",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: BuildBoxShadowContainer(
                circleRadius: 16,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.print_rounded,
                              color: ColorManager.kPrimaryColor,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Printer Settings',
                              style: TextStyle(
                                color: ColorManager.kTitleTextColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            CustomRoundButton(
                              fct: () => {clearLocalStorageAndLogout()},
                              title: 'Clear Local Storage',
                              height: 40,
                              width: 220,
                              fontSize: 14,
                              borderColor: Colors.orange,
                              boxColor: Colors.orange,
                              textColor: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            CustomRoundButton(
                              fct: () => {clearDefaultPrinter()},
                              title: 'Clear Default Printer',
                              height: 40,
                              width: 200,
                              fontSize: 14,
                              borderColor: ColorManager.kButtonRed,
                              boxColor: ColorManager.kButtonRed,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Current Default Printer Section
                    if (selectedPrinter != null)
                      BuildBoxShadowContainer(
                        circleRadius: 7,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Default Printer',
                              style: TextStyle(
                                color: ColorManager.kPrimaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: ColorManager.kPrimaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(
                                    Icons.print,
                                    color: ColorManager.kPrimaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedPrinter!.deviceName ??
                                            'Unknown Printer',
                                        style: const TextStyle(
                                          color: ColorManager.kTitleTextColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Type: ${selectedPrinter!.typePrinter}',
                                        style: const TextStyle(
                                          color: ColorManager.kGreyColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Paper Size Selection
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Default Paper Size',
                            style: TextStyle(
                              color: ColorManager.kPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text(
                                'Paper Size:',
                                style: TextStyle(
                                  color: ColorManager.kTitleTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: DropdownButton<String>(
                                  value: selectedPaperSize,
                                  underline: const SizedBox(),
                                  items: paperSizes.map((String size) {
                                    return DropdownMenuItem<String>(
                                      value: size,
                                      child: Text(size),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        selectedPaperSize = newValue;
                                      });
                                      _saveDefaultPaperSize(newValue);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Font Style Selection & Sample Print
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Font Style & Sample Print',
                                style: TextStyle(
                                  color: ColorManager.kPrimaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // CustomRoundButton(
                              //   fct: () => _printSample(),
                              //   title: 'Print Sample',
                              //   height: 36,
                              //   width: 120,
                              //   fontSize: 12,
                              //   borderColor: ColorManager.kPrimaryColor,
                              //   boxColor: ColorManager.kPrimaryColor,
                              //   textColor: Colors.white,
                              // ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text(
                                'Font Style:',
                                style: TextStyle(
                                  color: ColorManager.kTitleTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: DropdownButton<String>(
                                  value: selectedFontStyle,
                                  underline: const SizedBox(),
                                  items: fontStyles.map((String style) {
                                    return DropdownMenuItem<String>(
                                      value: style,
                                      child: Text(style),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        selectedFontStyle = newValue;
                                      });
                                      _saveDefaultFontStyle(newValue);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Select a font style and print a sample receipt with dummy data to test how it looks on your printer.',
                            style: TextStyle(
                              color: ColorManager.kGreyColor.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Available Printers Section
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Available Printers',
                                style: TextStyle(
                                  color: ColorManager.kPrimaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              CustomRoundButton(
                                fct: () =>
                                    _isScanning ? null : _checkPermissions(),
                                title: _isScanning ? 'Scanning...' : 'Scan',
                                height: 36,
                                width: 100,
                                fontSize: 12,
                                borderColor: _isScanning
                                    ? ColorManager.kGreyColor
                                    : ColorManager.kPrimaryColor,
                                boxColor: _isScanning
                                    ? ColorManager.kGreyColor
                                    : ColorManager.kPrimaryColor,
                                textColor: Colors.white,
                                isLoading: _isScanning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning
                                ? 'Scanning for printers...'
                                : '${devices.length} devices found',
                            style: const TextStyle(
                              color: ColorManager.kGreyColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Printers List
                          devices.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.print_disabled,
                                        size: 48,
                                        color: ColorManager.kGreyColor,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No printers found',
                                        style: TextStyle(
                                          color: ColorManager.kGreyColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap the scan button to search for printers',
                                        style: TextStyle(
                                          color: ColorManager.kGreyColor
                                              .withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: devices.length,
                                  itemBuilder: (context, index) {
                                    final printer = devices[index];
                                    final isSelected =
                                        selectedPrinter?.deviceName ==
                                                printer.deviceName &&
                                            selectedPrinter?.address ==
                                                printer.address;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(
                                                color:
                                                    ColorManager.kPrimaryColor,
                                                width: 2)
                                            : Border.all(
                                                color: Colors.grey[300]!),
                                        color: isSelected
                                            ? ColorManager.kPrimaryColor
                                                .withOpacity(0.1)
                                            : Colors.grey[50],
                                      ),
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.print,
                                          color: isSelected
                                              ? ColorManager.kPrimaryColor
                                              : ColorManager.kGreyColor,
                                          size: 28,
                                        ),
                                        title: Text(
                                          printer.deviceName ??
                                              'Unknown device',
                                          style: TextStyle(
                                            color: ColorManager.kTitleTextColor,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Text(
                                          printer.address ??
                                              printer.typePrinter,
                                          style: const TextStyle(
                                            color: ColorManager.kGreyColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        trailing: CustomRoundButton(
                                          fct: () => selectPrinter(printer),
                                          title: isSelected
                                              ? 'Selected'
                                              : 'Select',
                                          height: 32,
                                          width: 80,
                                          fontSize: 12,
                                          borderColor: isSelected
                                              ? ColorManager.kPrimaryColor
                                              : ColorManager.kGreyColor,
                                          boxColor: isSelected
                                              ? ColorManager.kPrimaryColor
                                              : Colors.white,
                                          textColor: isSelected
                                              ? Colors.white
                                              : ColorManager.kGreyColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
