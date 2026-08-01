import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:pos_machine/screens/print/widgets/printer_settings_responsive.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/services/printer_permission_service.dart';

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
  String selectedSegment = 'B2C'; // 'B2C' or 'B2B' (Billing tab only)
  String selectedReceiptTheme = 'classic'; // Receipt theme selection

  // Printer scanning variables
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  bool _isScanning = false;
  bool _isResyncingDocConfig = false;
  bool _developerModeEnabled = false;
  int _settingsLoadVersion = 0;

  // List of available paper sizes
  final List<String> paperSizes = ['112mm', '80mm', '58mm', 'A5', 'A4'];

  // List of available font styles
  final List<String> fontStyles = [
    'Font A (Small & Sharp)',
    'Font B (Default)',
  ];

  // List of available receipt themes for thermal printing (112mm/80mm/58mm)
  final List<Map<String, String>> thermalReceiptThemes = [
    {'id': 'classic', 'name': 'Classic'},
    {'id': 'premium', 'name': 'Premium'},
    {'id': 'premium1', 'name': 'Premium 1'},
    {'id': 'premium2', 'name': 'Premium 2'},
    {'id': 'premium2_bilingual', 'name': 'Premium 2 Bilingual'},
    {'id': 'supermarket_en', 'name': 'Supermarket En'},
    {'id': 'standard', 'name': 'Standard'},
    {'id': 'arabic_and_english', 'name': 'Arabic&English'},
    {'id': 'arabic_english_table_headers', 'name': 'Arabic&English 2'},
    {'id': 'arabic_and_english_3', 'name': 'Arabic&English 3'},
    {'id': 'supermarket', 'name': 'Supermarket'},
    {'id': 'supermarket2', 'name': 'Supermarket 2'},
    {'id': 'supermarket2_bilingual', 'name': 'Supermarket 2 Bilingual'},
    {'id': 'supermarkerrecpt3', 'name': 'Supermarker Recpt3'},
    {'id': 'bilingual', 'name': 'Bilingual'},
    {'id': 'multi_store', 'name': 'Multi Store'},
    {'id': 'mobile_shop_tax_invoice', 'name': 'Mobile Shop Tax Invoice'},
  ];

  // List of available receipt themes for standard PDF printing (A4/A5)
  final List<Map<String, String>> standardPdfThemes = [
    {'id': 'classic', 'name': 'Classic'},
    {'id': 'simplified_tax_invoice', 'name': 'Simplified Tax Invoice'},
    {
      'id': 'centered_simplified_tax_invoice',
      'name': 'Centered Simplified Tax Invoice'
    },
    {
      'id': 'bilingual_centered_tax_invoice',
      'name': 'Bilingual Centered Tax Invoice'
    },
    {
      'id': 'boxed_bilingual_tax_invoice',
      'name': 'Boxed Bilingual Tax Invoice'
    },
  ];

  /// Returns the appropriate theme list based on selected paper size
  List<Map<String, String>> get _activeThemes {
    if (selectedPaperSize == 'A4' || selectedPaperSize == 'A5') {
      return standardPdfThemes;
    }
    return thermalReceiptThemes;
  }

  /// Whether the current paper size is for standard PDF (A4/A5)
  bool get _isStandardPdf =>
      selectedPaperSize == 'A4' || selectedPaperSize == 'A5';

  bool get _usesReceiptSettings =>
      selectedSettingsType == 'Billing' || selectedSettingsType == 'Quotation';

  bool get _supportsDevelopmentPrinter => _usesReceiptSettings;

  List<BluetoothPrinter> get _displayDevices {
    if (!_developerModeEnabled || !_supportsDevelopmentPrinter) {
      return devices;
    }
    return [
      BluetoothPrinter.development(),
      ...devices.where((printer) => !printer.isDevelopment),
    ];
  }

  /// True when editing the B2B variant of the Billing settings.
  bool get _isB2BSegment =>
      selectedSettingsType == 'Billing' && selectedSegment == 'B2B';

  String get _printerPrefsKey {
    switch (selectedSettingsType) {
      case 'Billing':
        return _isB2BSegment ? 'default_printer_b2b' : 'default_printer';
      case 'Quotation':
        return 'quotation_printer';
      case 'Barcode':
        return 'barcode_printer';
      default:
        return 'kot_printer';
    }
  }

  String get _paperSizePrefsKey {
    switch (selectedSettingsType) {
      case 'Billing':
        return _isB2BSegment ? 'default_paper_size_b2b' : 'default_paper_size';
      case 'Quotation':
        return 'quotation_paper_size';
      default:
        return 'kot_paper_size';
    }
  }

  String get _fontStylePrefsKey {
    switch (selectedSettingsType) {
      case 'Billing':
        return 'default_font_style';
      case 'Quotation':
        return 'quotation_font_style';
      default:
        return 'kot_font_style';
    }
  }

  String get _receiptThemePrefsKey {
    switch (selectedSettingsType) {
      case 'Billing':
        return _isB2BSegment
            ? 'billing_receipt_theme_b2b'
            : 'billing_receipt_theme';
      case 'Quotation':
        return 'quotation_receipt_theme';
      default:
        return 'kot_receipt_theme';
    }
  }

  /// Returns a description for the selected theme
  String _getThemeDescription(String themeId) {
    if (_isStandardPdf) {
      switch (themeId) {
        case 'classic':
          return 'Traditional A4/A5 PDF layout with standard formatting';
        case 'tax_invoice':
          return 'Formal ZATCA-compliant bilingual Tax Invoice layout';
        case 'detailed_tax_invoice':
          return 'Comprehensive Tax Invoice with detailed itemization and tax breakdown';
        case 'standard_tax_invoice':
          return 'Clean Tax Invoice layout with essential details and clear tax info';
        case 'simplified_tax_invoice':
          return 'ZATCA Simplified Tax Invoice with teal accent header/footer, bilingual columns and totals';
        case 'centered_simplified_tax_invoice':
          return 'Simplified Tax Invoice with Arabic details on the left, a centered logo and English details on the right';
        case 'bilingual_centered_tax_invoice':
          return 'Bilingual centered Tax Invoice with Arabic details on the left, a centered logo and English details on the right';
        case 'boxed_bilingual_tax_invoice':
          return 'Boxed bilingual Tax Invoice with seller, buyer, invoice, items, bank and totals sections';
        case 'corporate_tax_invoice':
          return 'Formal corporate Tax Invoice with logo header, buyer block, bank details and bilingual amount in words';
        case 'letterhead_tax_invoice':
          return 'Bilingual Tax Invoice with tri-column letterhead (EN/logo/AR), boxed title and bordered customer/invoice boxes';
        case 'new_classic':
          return 'Modern A4/A5 layout with enhanced font hierarchy and breathable spacing';
        default:
          return 'Standard PDF layout';
      }
    }
    switch (themeId) {
      case 'classic':
        return 'Traditional receipt layout with standard formatting';
      case 'arabic_and_english':
        return 'Bilingual layout optimized for Arabic and English';
      case 'arabic_english_table_headers':
        return 'Arabic and English layout with bilingual table headers only';
      case 'arabic_and_english_3':
        return 'Bilingual layout with English name only.';
      case 'premium':
        return 'Premium design with enhanced visual styling and layout';
      case 'premium1':
        return 'Premium design with enhanced visual styling';
      case 'premium2':
        return 'Premium design with enhanced visual styling and invoice number in box';
      case 'premium2_bilingual':
        return 'Pilot clone of Premium 2 for language-driven bilingual and direction testing';
      case 'standard':
        return 'Clean and minimal receipt layout';
      case 'supermarket':
        return 'Modern & clean design with enhanced spacing';
      case 'supermarket2':
        return 'Modern with Delivery Icon';
      case 'supermarkerrecpt3':
        return 'Supermarket-style receipt layout (version 3)';
      case 'bilingual':
        return 'Bilingual layout with English and Arabic support';
      case 'mobile_shop_tax_invoice':
        return 'Bilingual ZATCA tax invoice for mobile shops with SN, VAT, QTY, PRICE and AMOUNT columns';
      default:
        return 'Modern & clean design with enhanced spacing';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSettings();
      if (mounted && !_developerModeEnabled) {
        _checkPermissions();
      }
    });
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
    if (!mounted) return;
    if (await _requestPermissions()) {
      if (!mounted) return;
      debugPrint('[PrinterSettings] Permissions granted. Proceeding to scan.');
      _scan();
    } else {
      debugPrint('[PrinterSettings] Permissions NOT granted. Showing dialog.');
      if (mounted) _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    debugPrint(
        '[PrinterSettings] _requestPermissions() platform(os)=${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      final granted =
          await PrinterPermissionService.requestRequiredPermissions();
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

  String _printerIdentity(BluetoothPrinter printer) => [
        printer.typePrinter.name,
        printer.address ?? '',
        printer.vendorId ?? '',
        printer.productId ?? '',
        printer.deviceName ?? '',
      ].join('|').toLowerCase();

  void _addDiscoveredPrinter(BluetoothPrinter printer) {
    if (!mounted) return;
    final identity = _printerIdentity(printer);
    if (devices.any((item) => _printerIdentity(item) == identity)) return;
    setState(() => devices.add(printer));
  }

  Future<void> _scan() async {
    if (_isScanning) {
      debugPrint(
          '[PrinterSettings] _scan() requested but a scan is already in progress. Ignoring.');
      return;
    }
    debugPrint(
        '[PrinterSettings] Starting scan... platform=${Platform.operatingSystem}');
    // Cancel any prior discovery subscription
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      if (Platform.isWindows) {
        debugPrint('[PrinterSettings] Discovering Windows spooler printers');
        final printers = await Printing.listPrinters();
        for (final printer in printers) {
          _addDiscoveredPrinter(BluetoothPrinter(
            deviceName: printer.name,
            address: printer.url,
            typePrinter: PrinterType.usb,
          ));
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        debugPrint(
            '[PrinterSettings] Beginning Bluetooth discovery (isBle=false)');
        final discoveryDone = Completer<void>();
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
          _addDiscoveredPrinter(printer);
        }, onError: (err) {
          debugPrint('[PrinterSettings] Bluetooth discovery error: $err');
          if (!discoveryDone.isCompleted) discoveryDone.complete();
        }, onDone: () {
          debugPrint(
              '[PrinterSettings] Bluetooth discovery done. Total BT devices: ${devices.where((p) => p.typePrinter == PrinterType.bluetooth).length}');
          if (!discoveryDone.isCompleted) discoveryDone.complete();
        }, cancelOnError: false);

        final timeout = Timer(const Duration(seconds: 12), () async {
          await _subscription?.cancel();
          if (!discoveryDone.isCompleted) discoveryDone.complete();
        });
        await discoveryDone.future;
        timeout.cancel();
      } else {
        debugPrint(
            '[PrinterSettings] Skipping Bluetooth discovery on desktop platform (${Platform.operatingSystem}).');
      }

      if (!Platform.isWindows) {
        debugPrint('[PrinterSettings] Beginning USB discovery');
        await printerManager.discovery(type: PrinterType.usb).forEach((device) {
          debugPrint(
              '[PrinterSettings] USB device found: name=${device.name}, vendorId=${device.vendorId}, productId=${device.productId}');
          _addDiscoveredPrinter(BluetoothPrinter(
            deviceName: device.name,
            vendorId: device.vendorId,
            productId: device.productId,
            typePrinter: PrinterType.usb,
          ));
        });
      }
      debugPrint(
          '[PrinterSettings] USB discovery completed. Total devices now: ${devices.length}');
    } catch (e, st) {
      debugPrint('[PrinterSettings] Error during scanning: $e');
      debugPrint('[PrinterSettings] Stacktrace: $st');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Could not scan for printers: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
      debugPrint(
          '[PrinterSettings] Scan finished. devices.length=${devices.length}');
    }
  }

  Future<void> selectPrinter(BluetoothPrinter printer) async {
    try {
      if (printer.isDevelopment) {
        if (!_developerModeEnabled || !_supportsDevelopmentPrinter) {
          throw StateError('Developer Mode is not enabled for this printer');
        }
        await DevelopmentPrinterService.selectForTarget(
          _printerPrefsKey,
          selected: true,
        );
      } else {
        await DevelopmentPrinterService.selectForTarget(
          _printerPrefsKey,
          selected: false,
        );
        await _saveDefaultPrinter(printer);
      }
      if (!mounted) return;
      setState(() => selectedPrinter = printer);
      showScaffold(
        context: context,
        message: printer.isDevelopment
            ? 'Development Printer selected. Prints will be saved to a folder.'
            : "${printer.deviceName.toString()} Printer Selected",
      );
    } catch (error) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: 'Could not save printer selection: $error',
      );
    }
  }

  Future<void> _saveDefaultPrinter(BluetoothPrinter printer) async {
    if (printer.isDevelopment) {
      throw ArgumentError(
          'Development printer must not replace a real printer');
    }
    final prefs = await SharedPreferences.getInstance();
    final printerData = {
      'deviceName': printer.deviceName,
      'address': printer.address,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'typePrinter': printer.typePrinter.toString(),
    };

    final saved =
        await prefs.setString(_printerPrefsKey, json.encode(printerData));
    if (!saved) throw StateError('Shared preferences write failed');
  }

  Future<void> _loadSettings() async {
    final requestVersion = ++_settingsLoadVersion;
    final settingsType = selectedSettingsType;
    final printerKey = _printerPrefsKey;
    final paperSizeKey = _paperSizePrefsKey;
    final fontStyleKey = _fontStylePrefsKey;
    final themeKey = _receiptThemePrefsKey;

    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final developerModeEnabled =
          await DevelopmentPrinterService.isEnabled(preferences: prefs);
      final developmentPrinterSelected = developerModeEnabled &&
          _supportsDevelopmentPrinter &&
          await DevelopmentPrinterService.shouldUseForTarget(
            printerKey,
            preferences: prefs,
          );
      final defaultPrinterJson = prefs.getString(printerKey);
      final defaultPaperSize =
          settingsType == 'Barcode' ? null : prefs.getString(paperSizeKey);
      final defaultFontStyle =
          settingsType == 'Barcode' ? null : prefs.getString(fontStyleKey);
      final savedTheme =
          settingsType == 'Barcode' ? null : prefs.getString(themeKey);

      var paperSize = defaultPaperSize ?? '80mm';
      if (paperSize == 'Thermal') {
        paperSize = '80mm';
        await prefs.setString(paperSizeKey, paperSize);
      }
      if (!paperSizes.contains(paperSize)) paperSize = '80mm';

      final fontStyle = fontStyles.contains(defaultFontStyle)
          ? defaultFontStyle!
          : 'Font A (Small & Sharp)';
      final themes = paperSize == 'A4' || paperSize == 'A5'
          ? standardPdfThemes
          : thermalReceiptThemes;
      final receiptTheme = themes.any((theme) => theme['id'] == savedTheme)
          ? savedTheme!
          : 'classic';

      BluetoothPrinter? printer;
      if (developmentPrinterSelected) {
        printer = BluetoothPrinter.development();
      } else if (defaultPrinterJson != null) {
        try {
          final printerData =
              json.decode(defaultPrinterJson) as Map<String, dynamic>;
          printer = BluetoothPrinter(
            deviceName: printerData['deviceName']?.toString(),
            address: printerData['address']?.toString(),
            vendorId: printerData['vendorId']?.toString(),
            productId: printerData['productId']?.toString(),
            typePrinter: PrinterType.values.firstWhere(
              (value) => value.toString() == printerData['typePrinter'],
              orElse: () => PrinterType.bluetooth,
            ),
          );
        } catch (error) {
          debugPrint('[PrinterSettings] Invalid saved printer: $error');
          await prefs.remove(printerKey);
        }
      }

      if (!mounted || requestVersion != _settingsLoadVersion) return;
      setState(() {
        selectedPaperSize = paperSize;
        selectedFontStyle = fontStyle;
        selectedReceiptTheme = receiptTheme;
        selectedPrinter = printer;
        _developerModeEnabled = developerModeEnabled;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _settingsLoadVersion) return;
      setState(() => isLoading = false);
      showScaffoldError(
        context: context,
        message: 'Could not load printer settings: $error',
      );
    }
  }

  Future<void> clearDefaultPrinter() async {
    try {
      setState(() {
        selectedPrinter = null;
        // Reset local state variables to defaults
        selectedPaperSize = '80mm';
        selectedFontStyle = 'Font A (Small & Sharp)';
      });

      // Also clear current context keys
      final prefs = await SharedPreferences.getInstance();
      await DevelopmentPrinterService.clearTargetSelection(
        _printerPrefsKey,
        preferences: prefs,
      );
      if (selectedSettingsType == 'Barcode') {
        await prefs.remove(_printerPrefsKey);
      } else {
        await prefs.remove(_printerPrefsKey);
        await prefs.remove(_paperSizePrefsKey);
        await prefs.remove(_fontStylePrefsKey);
        await prefs.remove(_receiptThemePrefsKey);
      }

      if (mounted) {
        showScaffold(
          context: context,
          message: "$selectedSettingsType printer settings reset to default",
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

  Future<void> _saveDefaultPaperSize(String paperSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paperSizePrefsKey, paperSize);

    if (mounted) {
      showScaffold(
        context: context,
        message: "Default paper size saved",
      );
    }
  }

  Future<void> _saveReceiptTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptThemePrefsKey, theme.toLowerCase());

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
    if (selectedPrinter!.isDevelopment) {
      showScaffoldError(
        context: context,
        message:
            'Development Printer previews are created from actual receipts. '
            'Print a bill or quotation to save its image.',
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
    final printerUtils = ThermalPrinterUtils();

    try {
      // Connect to printer
      await printerUtils.connectToPrinter(printer);

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
      await printerUtils.sendPrintJob(printer, bytes);
    } finally {
      await printerUtils.disconnectPrinter(printer);
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
    final body = isLoading
        ? const PrinterSettingsLoadingState()
        : selectedSettingsType == 'Barcode'
            ? _buildBarcodeBody()
            : _buildDefaultBody();

    return PrinterSettingsPageShell(
      scrollable: selectedSettingsType != 'Barcode',
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: body,
        ),
      ),
    );
  }

  /// Body for Barcode tab — header & tabs fixed, barcode panel fills remaining space
  Widget _buildBarcodeBody() {
    final gap = printerSectionGap(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        SizedBox(height: gap),
        _buildTabToggle(),
        SizedBox(height: gap),
        Expanded(
          child: BarcodeLayoutSettingsPanel(
            printerListWidget: _buildPrinterList(),
          ),
        ),
      ],
    );
  }

  /// Body for Billing / Kitchen tabs — everything scrolls
  Widget _buildDefaultBody() {
    final gap = printerSectionGap(context);
    final isCompact = printerIsCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        SizedBox(height: gap),
        _buildTabToggle(),
        if (selectedSettingsType == 'Billing') ...[
          SizedBox(height: isCompact ? 8 : 4),
          _buildSegmentToggle(),
        ],
        SizedBox(height: gap),
        PrinterSettingsSplitLayout(
          settingsColumn: _buildSettingsSection(),
          printerColumn: _buildPrinterList(),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    final cardPadding = printerCardPadding(context);
    final fieldGap = printerIsCompact(context) ? 12.0 : 20.0;
    final cardGap = printerSectionGap(context);

    return Column(
      children: [
        PrinterSettingsCard(
          padding: cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PrinterSectionHeader(
                icon: Icons.description_rounded,
                title: 'Paper Size Settings',
                subtitle: 'Choose the default paper width for receipts',
              ),
              SizedBox(height: fieldGap),
              PrinterDropdownField(
                label: 'Paper Size',
                value: paperSizes.contains(selectedPaperSize)
                    ? selectedPaperSize
                    : '80mm',
                items: paperSizes.map((String size) {
                  return DropdownMenuItem<String>(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    final wasThermal = selectedPaperSize == '112mm' ||
                        selectedPaperSize == '80mm' ||
                        selectedPaperSize == '58mm';
                    final willBeThermal = newValue == '112mm' ||
                        newValue == '80mm' ||
                        newValue == '58mm';

                    setState(() {
                      selectedPaperSize = newValue;

                      // Reset theme if crossing thermal↔standard boundary
                      // and current theme doesn't exist in the new list
                      if (wasThermal != willBeThermal) {
                        final newThemes = _activeThemes;
                        final themeExists = newThemes
                            .any((t) => t['id'] == selectedReceiptTheme);
                        if (!themeExists) {
                          selectedReceiptTheme = 'classic';
                          _saveReceiptTheme('classic');
                        }
                      }
                    });
                    _saveDefaultPaperSize(newValue);
                  }
                },
              ),
            ],
          ),
        ),
        SizedBox(height: cardGap),
        if (_usesReceiptSettings)
          PrinterSettingsCard(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PrinterSectionHeader(
                  icon: Icons.palette_outlined,
                  title: 'Receipt Theme',
                  subtitle: 'Select the visual layout for printed receipts',
                ),
                SizedBox(height: fieldGap),
                PrinterDropdownField(
                  label: 'Theme',
                  value: selectedReceiptTheme,
                  items: _activeThemes.map((Map<String, String> theme) {
                    return DropdownMenuItem<String>(
                      value: theme['id'],
                      child: Text(theme['name']!),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedReceiptTheme = newValue;
                      });
                      _saveReceiptTheme(newValue);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _getThemeDescription(selectedReceiptTheme),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.10,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

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
      ],
    );
  }

  Widget _buildHeader() {
    final isCompact = printerIsCompact(context);
    final cardPadding = printerCardPadding(context);

    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: isCompact ? 40 : 48,
          width: isCompact ? 40 : 48,
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
          ),
          child: Icon(
            Icons.print_rounded,
            color: ColorManager.kPrimaryColor,
            size: isCompact ? 22 : 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Printer Settings',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  isCompact ? FontSize.s18 : FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Configure printers, paper sizes and receipt themes',
                maxLines: isCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.10,
                  Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actionRow = SettingsActionRow(
      children: [
        if (selectedSettingsType != 'Barcode' && !_isStandardPdf)
          CustomRoundButton(
            fct: _printSample,
            title: 'Test Print',
            height: 44,
            width: isCompact ? double.infinity : 120,
            fontSize: 14,
            borderColor: ColorManager.kPrimaryColor,
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
          ),
        CustomRoundButton(
          fct: _isResyncingDocConfig ? () {} : _resyncDocumentConfigurations,
          title: _isResyncingDocConfig
              ? 'Resyncing...'
              : (isCompact ? 'Resync Doc' : 'Resync Doc Config'),
          height: 44,
          width: isCompact ? double.infinity : 180,
          fontSize: isCompact ? 13 : 14,
          borderColor: ColorManager.kPrimaryColor,
          boxColor: ColorManager.kPrimaryColor,
          textColor: Colors.white,
          isLoading: _isResyncingDocConfig,
        ),
        CustomRoundButton(
          fct: () => {clearDefaultPrinter()},
          title: isCompact ? 'Clear' : 'Clear Default Printer',
          height: 44,
          width: isCompact ? double.infinity : 170,
          fontSize: isCompact ? 13 : 14,
          borderColor: ColorManager.kButtonRed,
          boxColor: ColorManager.kButtonRed,
          textColor: Colors.white,
        ),
      ],
    );

    return PrinterSettingsCard(
      padding: cardPadding,
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                actionRow,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                actionRow,
              ],
            ),
    );
  }

  Widget _buildTabToggle() {
    return PrinterTabSelector(
      selectedType: selectedSettingsType,
      onSelected: (type) {
        setState(() {
          selectedSettingsType = type;
        });
        _loadSettings();
      },
    );
  }

  /// B2C / B2B segment toggle, shown only for the Billing tab. Each segment
  /// keeps its own printer, paper size and receipt theme. B2B falls back to the
  /// B2C settings at print time when not separately configured.
  Widget _buildSegmentToggle() {
    return PrinterSegmentSelector(
      selectedSegment: selectedSegment,
      onSelected: (segment) {
        if (selectedSegment == segment) return;
        setState(() {
          selectedSegment = segment;
        });
        _loadSettings();
      },
      helperText: 'Configure a separate printer, paper size and theme for '
          '${selectedSegment == 'B2B' ? 'business (B2B)' : 'retail (B2C)'} '
          'bills. B2B uses the B2C settings when left unconfigured.',
    );
  }

  Widget _buildPrinterList() {
    final isCompact = printerIsCompact(context);
    final cardPadding = printerCardPadding(context);
    final listGap = printerSectionGap(context);
    final displayDevices = _displayDevices;

    return PrinterSettingsCard(
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.devices_rounded,
            title: 'Available Printers',
            subtitle: _developerModeEnabled && _supportsDevelopmentPrinter
                ? 'Select a physical printer or save output to a folder'
                : 'Scan and select a default printer',
            trailing: CustomRoundButton(
              fct: () => _isScanning ? null : _checkPermissions(),
              title: _isScanning ? 'Scanning...' : 'Scan for Printers',
              height: 44,
              width: isCompact ? double.infinity : 160,
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
          ),
          SizedBox(height: listGap),
          PrinterInfoStrip(
            text: _isScanning
                ? 'Scanning for printers...'
                : '${displayDevices.length} devices found',
            icon: _isScanning
                ? Icons.bluetooth_searching_rounded
                : Icons.devices_other_rounded,
          ),
          if (selectedPrinter != null) ...[
            const SizedBox(height: 10),
            SettingsStatusBadge(
              label: selectedPrinter!.deviceName ?? 'Printer selected',
              isPositive: true,
              icon: Icons.check_circle_outline_rounded,
            ),
            if (selectedPrinter!.isDevelopment) ...[
              const SizedBox(height: 10),
              FutureBuilder<Directory>(
                future: DevelopmentPrinterService.getOutputDirectory(),
                builder: (context, snapshot) => PrinterInfoStrip(
                  text: snapshot.hasData
                      ? 'Output folder: ${snapshot.data!.path}'
                      : 'Preparing development output folder...',
                  icon: Icons.folder_outlined,
                ),
              ),
            ],
          ],
          SizedBox(height: listGap),
          displayDevices.isEmpty
              ? const PrinterEmptyState(
                  title: 'No printers found',
                  subtitle:
                      'Tap the scan button above to search for nearby printers',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayDevices.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final printer = displayDevices[index];
                    final isSelected = selectedPrinter != null &&
                        _printerIdentity(selectedPrinter!) ==
                            _printerIdentity(printer);

                    return _buildPrinterDeviceTile(
                      printer: printer,
                      isSelected: isSelected,
                      isCompact: isCompact,
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildPrinterDeviceTile({
    required BluetoothPrinter printer,
    required bool isSelected,
    required bool isCompact,
  }) {
    final deviceName = printer.deviceName ?? 'Unknown device';
    final subtitle = printer.isDevelopment
        ? 'Saves PDFs and thermal receipt images to a local folder'
        : printer.address ?? printer.typePrinter.name;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorManager.kPrimaryColor.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ColorManager.kPrimaryColor.withValues(alpha: 0.35)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorManager.kPrimaryColor.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: isSelected
                        ? ColorManager.kPrimaryColor
                        : ColorManager.kGreyColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          isSelected
                              ? FontWeightManager.semiBold
                              : FontWeightManager.medium,
                          FontSize.s14,
                          0.18,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.10,
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CustomRoundButton(
              fct: () => selectPrinter(printer),
              title: isSelected ? 'Selected' : 'Select',
              height: 44,
              width: double.infinity,
              fontSize: 14,
              borderColor: isSelected
                  ? ColorManager.kPrimaryColor
                  : ColorManager.kGreyColor,
              boxColor: isSelected ? ColorManager.kPrimaryColor : Colors.white,
              textColor: isSelected ? Colors.white : ColorManager.kGreyColor,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? ColorManager.kPrimaryColor.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? ColorManager.kPrimaryColor.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minVerticalPadding: 0,
        leading: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: isSelected
                ? ColorManager.kPrimaryColor.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(
            Icons.print_rounded,
            color: isSelected
                ? ColorManager.kPrimaryColor
                : ColorManager.kGreyColor,
          ),
        ),
        title: Text(
          deviceName,
          style: buildCustomStyle(
            isSelected ? FontWeightManager.semiBold : FontWeightManager.medium,
            FontSize.s14,
            0.18,
            ColorManager.textColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.10,
              Colors.grey.shade600,
            ),
          ),
        ),
        trailing: CustomRoundButton(
          fct: () => selectPrinter(printer),
          title: isSelected ? 'Selected' : 'Select',
          height: 44,
          width: 108,
          fontSize: 14,
          borderColor:
              isSelected ? ColorManager.kPrimaryColor : ColorManager.kGreyColor,
          boxColor: isSelected ? ColorManager.kPrimaryColor : Colors.white,
          textColor: isSelected ? Colors.white : ColorManager.kGreyColor,
        ),
      ),
    );
  }
}
