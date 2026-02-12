import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/helpers/date_helper.dart';
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
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/providers/document_config_provider.dart';

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
  String selectedSettingsType = 'Billing'; // 'Billing' or 'Kitchen'
  String selectedReceiptTheme = 'classic'; // Receipt theme selection

  // Printer scanning variables
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  bool _isScanning = false;
  bool _isResyncingDocConfig = false;

  // List of available paper sizes
  final List<String> paperSizes = ['80mm', '58mm', 'A5', 'A4'];

  // List of available font styles
  final List<String> fontStyles = [
    'Font A (Small & Sharp)',
    'Font B (Default)',
  ];

  // List of available receipt themes
  final List<Map<String, String>> receiptThemes = [
    {'id': 'classic', 'name': 'Classic'},
    {'id': 'premium', 'name': 'Premium'},
    {'id': 'premium1', 'name': 'Premium 1'},
    {'id': 'standard', 'name': 'Standard'},
    {'id': 'arabic_and_english', 'name': 'Arabic&English'},
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
    debugPrint(
        '[PrinterSettings] dispose(): canceling discovery subscription if any');
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    debugPrint('[PrinterSettings] _checkPermissions() called');
    if (await _requestPermissions()) {
      debugPrint('[PrinterSettings] Permissions granted. Proceeding to scan.');
      _scan();
    } else {
      debugPrint('[PrinterSettings] Permissions NOT granted. Showing dialog.');
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    debugPrint(
        '[PrinterSettings] _requestPermissions() platform(os)=${Platform.operatingSystem} theme=${Theme.of(context).platform}');
    if (Theme.of(context).platform == TargetPlatform.android) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      statuses.forEach((perm, status) {
        debugPrint(
            '[PrinterSettings] Permission ${perm.toString()} => ${status.toString()}');
      });

      final granted = statuses.values.every((status) => status.isGranted);
      debugPrint('[PrinterSettings] All permissions granted: $granted');
      return granted;
    }
    debugPrint(
        '[PrinterSettings] Non-Android platform; skipping runtime permission request.');
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
          '[PrinterSettings] _scan() requested but a scan is already in progress. Ignoring.');
      return;
    }
    debugPrint(
        '[PrinterSettings] Starting scan... platform=${Platform.operatingSystem}');
    // Cancel any prior discovery subscription
    await _subscription?.cancel();
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Bluetooth discovery only on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint(
            '[PrinterSettings] Beginning Bluetooth discovery (isBle=false)');
        _subscription = printerManager
            .discovery(type: PrinterType.bluetooth, isBle: false)
            .listen((device) {
          debugPrint(
              '[PrinterSettings] BT device found: name=${device.name}, address=${device.address}');
          final printer = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            typePrinter: PrinterType.bluetooth,
          );
          setState(() {
            devices.add(printer);
          });
        }, onError: (err) {
          debugPrint('[PrinterSettings] Bluetooth discovery error: $err');
        }, onDone: () {
          debugPrint(
              '[PrinterSettings] Bluetooth discovery done. Total BT devices: ${devices.where((p) => p.typePrinter == PrinterType.bluetooth.toString()).length}');
        }, cancelOnError: false);
      } else {
        debugPrint(
            '[PrinterSettings] Skipping Bluetooth discovery on desktop platform (${Platform.operatingSystem}).');
      }

      debugPrint('[PrinterSettings] Beginning USB discovery');
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        debugPrint(
            '[PrinterSettings] USB device found: name=${device.name}, vendorId=${device.vendorId}, productId=${device.productId}');
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
          '[PrinterSettings] USB discovery completed. Total devices now: ${devices.length}');
    } catch (e, st) {
      debugPrint('[PrinterSettings] Error during scanning: $e');
      debugPrint('[PrinterSettings] Stacktrace: $st');
    } finally {
      setState(() {
        _isScanning = false;
      });
      debugPrint(
          '[PrinterSettings] Scan finished. devices.length=${devices.length}');
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

    // Save to appropriate key based on selected type
    final key =
        selectedSettingsType == 'Billing' ? 'default_printer' : 'kot_printer';
    await prefs.setString(key, json.encode(printerData));
  }

  Future<void> _loadSettings() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    // Determine keys based on selected type
    final printerKey =
        selectedSettingsType == 'Billing' ? 'default_printer' : 'kot_printer';
    final paperSizeKey = selectedSettingsType == 'Billing'
        ? 'default_paper_size'
        : 'kot_paper_size';
    final fontStyleKey = selectedSettingsType == 'Billing'
        ? 'default_font_style'
        : 'kot_font_style';
    final themeKey = selectedSettingsType == 'Billing'
        ? 'billing_receipt_theme'
        : 'kot_receipt_theme';

    final defaultPrinterJson = prefs.getString(printerKey);
    final defaultPaperSize = prefs.getString(paperSizeKey);
    final defaultFontStyle = prefs.getString(fontStyleKey);
    final savedTheme = prefs.getString(themeKey);

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
      // Don't auto-save default here to avoid overwriting if just switching tabs
    }

    // Load font style
    if (defaultFontStyle != null) {
      setState(() {
        selectedFontStyle = defaultFontStyle;
      });
    } else {
      // Default to Font A if no preference is set
      setState(() {
        selectedFontStyle = 'Font A (Small & Sharp)';
      });
    }

    // Load receipt theme
    if (savedTheme != null) {
      setState(() {
        selectedReceiptTheme = savedTheme;
      });
    } else {
      // Default to classic if no preference is set
      setState(() {
        selectedReceiptTheme = 'classic';
      });
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
          typePrinter: PrinterType.values.firstWhere(
            (e) => e.toString() == printerData['typePrinter'],
            orElse: () => PrinterType.bluetooth,
          ),
        );
      });
    } else {
      setState(() {
        selectedPrinter = null;
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> clearDefaultPrinter() async {
    try {
      // Use the provider to clear all printer settings (printer, paper size, font style)
      await SharedPreferenceProvider().clearPrinterSettings();

      setState(() {
        selectedPrinter = null;
        // Reset local state variables to defaults
        selectedPaperSize = '80mm';
        selectedFontStyle = 'Font A (Small & Sharp)';
      });

      // Also clear current context keys
      final prefs = await SharedPreferences.getInstance();
      if (selectedSettingsType == 'Billing') {
        await prefs.remove('default_printer');
        await prefs.remove('default_paper_size');
        await prefs.remove('default_font_style');
      } else {
        await prefs.remove('kot_printer');
        await prefs.remove('kot_paper_size');
        // await prefs.remove('kot_font_style'); // If added later
      }

      if (mounted) {
        showScaffold(
          context: context,
          message: "All printer settings reset to default",
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error resetting printer settings: ${e.toString()}",
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
    final key = selectedSettingsType == 'Billing'
        ? 'default_paper_size'
        : 'kot_paper_size';
    await prefs.setString(key, paperSize);

    if (mounted) {
      showScaffold(
        context: context,
        message: "Default paper size saved",
      );
    }
  }

  Future<void> _saveDefaultFontStyle(String fontStyle) async {
    final prefs = await SharedPreferences.getInstance();
    final key = selectedSettingsType == 'Billing'
        ? 'default_font_style'
        : 'kot_font_style';
    await prefs.setString(key, fontStyle);

    if (mounted) {
      showScaffold(
        context: context,
        message: "Default font style saved",
      );
    }
  }

  Future<void> _saveReceiptTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    final key = selectedSettingsType == 'Billing'
        ? 'billing_receipt_theme'
        : 'kot_receipt_theme';
    await prefs.setString(key, theme.toLowerCase());

    if (mounted) {
      showScaffold(
        context: context,
        message: "Receipt theme saved",
      );
    }
  }

  Future<void> _resyncDocumentConfigurations() async {
    if (_isResyncingDocConfig) return;

    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Missing access token. Please login again.',
      );
      return;
    }

    setState(() {
      _isResyncingDocConfig = true;
    });

    try {
      final docProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      await docProvider.clearAllCaches();
      await docProvider.fetchDocumentConfigurations(accessToken: accessToken);

      if (!mounted) return;
      showScaffold(
        context: context,
        message: 'Document configuration resynced successfully',
      );
    } catch (e) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Failed to resync document configurations: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResyncingDocConfig = false;
        });
      }
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
      final now = DateHelper.now();
      bytes += generator.row([
        PosColumn(
            text: '${now.day}/${now.month}/${now.year}',
            width: 6,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.left,
                bold: true,
                height: textSizeSmall)),
        PosColumn(
            text: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
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
      await printerManager.send(type: printer.typePrinter, bytes: bytes);
    } finally {
      await _disconnectPrinter(printer);
    }
  }

  Future<void> _connectToPrinter(BluetoothPrinter selectedPrinter) async {
    if (selectedPrinter.typePrinter == PrinterType.usb) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: selectedPrinter.deviceName ?? 'Unknown',
          productId: selectedPrinter.productId,
          vendorId: selectedPrinter.vendorId,
        ),
      );
    } else if (selectedPrinter.typePrinter == PrinterType.bluetooth) {
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
      await printerManager.disconnect(type: selectedPrinter.typePrinter);
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
      if (Hive.isBoxOpen('categories')) {
        await Hive.box<HiveCategory>('categories').close();
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
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    ColorManager.kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.print_rounded,
                                color: ColorManager.kPrimaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
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
                              fct: _isResyncingDocConfig
                                  ? () {}
                                  : _resyncDocumentConfigurations,
                              title: _isResyncingDocConfig
                                  ? 'Resyncing...'
                                  : 'Resync Doc Config',
                              height: 44,
                              width: 210,
                              fontSize: 14,
                              borderColor: ColorManager.kPrimaryColor,
                              boxColor: ColorManager.kPrimaryColor,
                              textColor: Colors.white,
                              isLoading: _isResyncingDocConfig,
                            ),
                            const SizedBox(width: 16),
                            CustomRoundButton(
                              fct: () => {clearLocalStorageAndLogout()},
                              title: 'Clear Local Storage',
                              height: 44,
                              width: 220,
                              fontSize: 14,
                              borderColor: Colors.orange,
                              boxColor: Colors.orange,
                              textColor: Colors.white,
                            ),
                            const SizedBox(width: 16),
                            CustomRoundButton(
                              fct: () => {clearDefaultPrinter()},
                              title: 'Clear Default Printer',
                              height: 44,
                              width: 180,
                              fontSize: 14,
                              borderColor: ColorManager.kButtonRed,
                              boxColor: ColorManager.kButtonRed,
                              textColor: Colors.white,
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current Default Printer Section
                  // if (selectedPrinter != null)
                  //   Container(
                  //     padding: const EdgeInsets.all(24),
                  //     decoration: BoxDecoration(
                  //       color: Colors.white,
                  //       borderRadius: BorderRadius.circular(12),
                  //       boxShadow: [
                  //         BoxShadow(
                  //           color: Colors.black.withOpacity(0.03),
                  //           blurRadius: 8,
                  //           offset: const Offset(0, 2),
                  //         ),
                  //       ],
                  //     ),
                  //     child: Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         Row(
                  //           children: [
                  //             Container(
                  //               padding: const EdgeInsets.all(8),
                  //               decoration: BoxDecoration(
                  //                 color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  //                 borderRadius: BorderRadius.circular(8),
                  //               ),
                  //               child: const Icon(
                  //                 Icons.check_circle_rounded,
                  //                 color: ColorManager.kPrimaryColor,
                  //                 size: 20,
                  //               ),
                  //             ),
                  //             const SizedBox(width: 12),
                  //             const Text(
                  //               'Current Default Printer',
                  //               style: TextStyle(
                  //                 color: ColorManager.kPrimaryColor,
                  //                 fontSize: 18,
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //         const SizedBox(height: 20),
                  //         Container(
                  //           padding: const EdgeInsets.all(20),
                  //           decoration: BoxDecoration(
                  //             color: ColorManager.kPrimaryColor.withOpacity(0.04),
                  //             borderRadius: BorderRadius.circular(12),
                  //           ),
                  //           child: Row(
                  //             children: [
                  //               Container(
                  //                 padding: const EdgeInsets.all(16),
                  //                 decoration: BoxDecoration(
                  //                   color: Colors.white,
                  //                   borderRadius: BorderRadius.circular(12),
                  //                 ),
                  //                 child: const Icon(
                  //                   Icons.print,
                  //                   color: ColorManager.kPrimaryColor,
                  //                   size: 32,
                  //                 ),
                  //               ),
                  //               const SizedBox(width: 20),
                  //               Expanded(
                  //                 child: Column(
                  //                   crossAxisAlignment: CrossAxisAlignment.start,
                  //                   children: [
                  //                     Text(
                  //                       selectedPrinter!.deviceName ?? 'Unknown Printer',
                  //                       style: const TextStyle(
                  //                         color: ColorManager.kTitleTextColor,
                  //                         fontSize: 20,
                  //                         fontWeight: FontWeight.bold,
                  //                       ),
                  //                     ),
                  //                     const SizedBox(height: 8),
                  //                     Container(
                  //                       padding: const EdgeInsets.symmetric(
                  //                         horizontal: 12,
                  //                         vertical: 6,
                  //                       ),
                  //                       decoration: BoxDecoration(
                  //                         color: Colors.white,
                  //                         borderRadius: BorderRadius.circular(20),
                  //                       ),
                  //                       child: Text(
                  //                         'Type: ${selectedPrinter!.typePrinter}',
                  //                         style: TextStyle(
                  //                           color: ColorManager.kPrimaryColor,
                  //                           fontSize: 14,
                  //                           fontWeight: FontWeight.w500,
                  //                         ),
                  //                       ),
                  //                     ),
                  //                   ],
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),

                  // if (selectedPrinter != null) const SizedBox(height: 24),

                  // Settings Type Toggle
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedSettingsType = 'Billing';
                              });
                              _loadSettings();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedSettingsType == 'Billing'
                                    ? ColorManager.kPrimaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Text(
                                'Billing Printer',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selectedSettingsType == 'Billing'
                                      ? Colors.white
                                      : ColorManager.kTitleTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedSettingsType = 'Kitchen';
                              });
                              _loadSettings();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedSettingsType == 'Kitchen'
                                    ? ColorManager.kPrimaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Text(
                                'Kitchen Printer',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selectedSettingsType == 'Kitchen'
                                      ? Colors.white
                                      : ColorManager.kTitleTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Settings Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Paper Size & Font Style Column
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            // Paper Size Selection
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.description_rounded,
                                          color: ColorManager.kPrimaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Paper Size Settings',
                                        style: TextStyle(
                                          color: ColorManager.kPrimaryColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Paper Size:',
                                          style: TextStyle(
                                            color: ColorManager.kTitleTextColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: DropdownButton<String>(
                                              value: selectedPaperSize,
                                              isExpanded: true,
                                              underline: const SizedBox(),
                                              items:
                                                  paperSizes.map((String size) {
                                                return DropdownMenuItem<String>(
                                                  value: size,
                                                  child: Text(size),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    selectedPaperSize =
                                                        newValue;
                                                  });
                                                  _saveDefaultPaperSize(
                                                      newValue);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Receipt Theme Selection (only for Billing)
                            if (selectedSettingsType == 'Billing')
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: ColorManager.kPrimaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.palette_outlined,
                                            color: ColorManager.kPrimaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Receipt Theme',
                                          style: TextStyle(
                                            color: ColorManager.kPrimaryColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'Theme:',
                                            style: TextStyle(
                                              color:
                                                  ColorManager.kTitleTextColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: DropdownButton<String>(
                                                value: selectedReceiptTheme,
                                                isExpanded: true,
                                                underline: const SizedBox(),
                                                items: receiptThemes.map(
                                                    (Map<String, String>
                                                        theme) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: theme['id'],
                                                    child: Text(theme['name']!),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  if (newValue != null) {
                                                    setState(() {
                                                      selectedReceiptTheme =
                                                          newValue;
                                                    });
                                                    _saveReceiptTheme(newValue);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedReceiptTheme == 'classic'
                                          ? 'Traditional receipt layout with standard formatting'
                                          : selectedReceiptTheme ==
                                                  'arabic_and_english'
                                              ? 'Bilingual layout optimized for Arabic and English'
                                              : 'Modern & clean design with enhanced spacing',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (selectedSettingsType == 'Billing')
                              const SizedBox(height: 24),

                            // Font Style Selection
                            // Container(
                            //   padding: const EdgeInsets.all(24),
                            //   decoration: BoxDecoration(
                            //     color: Colors.white,
                            //     borderRadius: BorderRadius.circular(12),
                            //     boxShadow: [
                            //       BoxShadow(
                            //         color: Colors.black.withOpacity(0.03),
                            //         blurRadius: 8,
                            //         offset: const Offset(0, 2),
                            //       ),
                            //     ],
                            //   ),
                            //   child: Column(
                            //     crossAxisAlignment: CrossAxisAlignment.start,
                            //     children: [
                            //       Row(
                            //         children: [
                            //           Container(
                            //             padding: const EdgeInsets.all(8),
                            //             decoration: BoxDecoration(
                            //               color: ColorManager.kPrimaryColor.withOpacity(0.1),
                            //               borderRadius: BorderRadius.circular(8),
                            //             ),
                            //             child: const Icon(
                            //               Icons.font_download_rounded,
                            //               color: ColorManager.kPrimaryColor,
                            //               size: 20,
                            //             ),
                            //           ),
                            //           const SizedBox(width: 12),
                            //           const Text(
                            //             'Font Style Settings',
                            //             style: TextStyle(
                            //               color: ColorManager.kPrimaryColor,
                            //               fontSize: 18,
                            //               fontWeight: FontWeight.bold,
                            //             ),
                            //           ),
                            //         ],
                            //       ),
                            //       const SizedBox(height: 24),
                            //       Container(
                            //         padding: const EdgeInsets.all(16),
                            //         decoration: BoxDecoration(
                            //           color: Colors.grey[50],
                            //           borderRadius: BorderRadius.circular(12),
                            //         ),
                            //         child: Row(
                            //           children: [
                            //             const Text(
                            //               'Font Style:',
                            //               style: TextStyle(
                            //                 color: ColorManager.kTitleTextColor,
                            //                 fontSize: 16,
                            //                 fontWeight: FontWeight.w500,
                            //               ),
                            //             ),
                            //             const SizedBox(width: 16),
                            //             Expanded(
                            //               child: Container(
                            //                 padding: const EdgeInsets.symmetric(horizontal: 16),
                            //                 decoration: BoxDecoration(
                            //                   color: Colors.white,
                            //                   borderRadius: BorderRadius.circular(8),
                            //                 ),
                            //                 child: DropdownButton<String>(
                            //                   value: selectedFontStyle,
                            //                   isExpanded: true,
                            //                   underline: const SizedBox(),
                            //                   items: fontStyles.map((String style) {
                            //                     return DropdownMenuItem<String>(
                            //                       value: style,
                            //                       child: Text(style),
                            //                     );
                            //                   }).toList(),
                            //                   onChanged: (String? newValue) {
                            //                     if (newValue != null) {
                            //                       setState(() {
                            //                         selectedFontStyle = newValue;
                            //                       });
                            //                       _saveDefaultFontStyle(newValue);
                            //                     }
                            //                   },
                            //                 ),
                            //               ),
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //       const SizedBox(height: 16),
                            //       Container(
                            //         padding: const EdgeInsets.all(12),
                            //         decoration: BoxDecoration(
                            //           color: Colors.blue[50],
                            //           borderRadius: BorderRadius.circular(8),
                            //         ),
                            //         child: Row(
                            //           children: [
                            //             Icon(
                            //               Icons.info_outline_rounded,
                            //               color: Colors.blue[700],
                            //               size: 20,
                            //             ),
                            //             const SizedBox(width: 12),
                            //             Expanded(
                            //               child: Text(
                            //                 'Select a font style and print a sample receipt to test how it looks.',
                            //                 style: TextStyle(
                            //                   color: Colors.blue[700],
                            //                   fontSize: 14,
                            //                 ),
                            //               ),
                            //             ),
                            //           ],
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Available Printers Section
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.devices_rounded,
                                          color: ColorManager.kPrimaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Available Printers',
                                        style: TextStyle(
                                          color: ColorManager.kPrimaryColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  CustomRoundButton(
                                    fct: () => _isScanning
                                        ? null
                                        : _checkPermissions(),
                                    title: _isScanning
                                        ? 'Scanning...'
                                        : 'Scan for Printers',
                                    height: 44,
                                    width: 160,
                                    fontSize: 14,
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
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isScanning
                                      ? 'Scanning for printers...'
                                      : '${devices.length} devices found',
                                  style: const TextStyle(
                                    color: ColorManager.kGreyColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Printers List
                              devices.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(40),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.print_disabled_rounded,
                                            size: 64,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No printers found',
                                            style: TextStyle(
                                              color: ColorManager.kGreyColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Click the scan button above to search for printers',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: devices.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final printer = devices[index];
                                        final isSelected =
                                            selectedPrinter?.deviceName ==
                                                    printer.deviceName &&
                                                selectedPrinter?.address ==
                                                    printer.address;

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? ColorManager.kPrimaryColor
                                                    .withOpacity(0.04)
                                                : Colors.grey[50],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 8,
                                            ),
                                            leading: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? ColorManager.kPrimaryColor
                                                        .withOpacity(0.1)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.print,
                                                color: isSelected
                                                    ? ColorManager.kPrimaryColor
                                                    : ColorManager.kGreyColor,
                                                size: 24,
                                              ),
                                            ),
                                            title: Text(
                                              printer.deviceName ??
                                                  'Unknown device',
                                              style: TextStyle(
                                                color: ColorManager
                                                    .kTitleTextColor,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                            ),
                                            subtitle: Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                printer.address ??
                                                    printer.typePrinter.name,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            trailing: CustomRoundButton(
                                              fct: () => selectPrinter(printer),
                                              title: isSelected
                                                  ? 'Selected'
                                                  : 'Select',
                                              height: 36,
                                              width: 100,
                                              fontSize: 14,
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
