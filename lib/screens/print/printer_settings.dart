import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
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
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';
import 'package:pos_machine/screens/print/widgets/printer_settings_responsive.dart';
import 'package:pos_machine/screens/print/widgets/common_print_margins_card.dart';
import 'package:pos_machine/screens/print/widgets/common_printer_settings_card.dart';
import 'package:pos_machine/screens/print/widgets/receipt_configuration_workspace.dart';
import 'package:pos_machine/screens/print/receipt_document_config_resolver.dart';
import 'package:pos_machine/screens/print/pdf_share_settings.dart';
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
  String selectedSettingsType = 'Billing';
  String selectedSegment = 'B2C';
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
  final List<Map<String, String>> standardPdfThemes = PdfShareSettings.themes;

  bool get _isPdfSharing => selectedSettingsType == 'PDF Sharing';

  List<String> get _activePaperSizes =>
      _isPdfSharing ? PdfShareSettings.paperSizes : paperSizes;

  /// Returns the appropriate theme list based on selected paper size
  List<Map<String, String>> get _activeThemes {
    if (_isPdfSharing ||
        selectedPaperSize == 'A4' ||
        selectedPaperSize == 'A5') {
      return standardPdfThemes;
    }
    return thermalReceiptThemes;
  }

  /// Whether the current paper size is for standard PDF (A4/A5)
  bool get _isStandardPdf =>
      selectedPaperSize == 'A4' || selectedPaperSize == 'A5';

  bool get _usesReceiptSettings =>
      selectedSettingsType == 'Billing' ||
      selectedSettingsType == 'Quotation' ||
      _isPdfSharing;

  bool get _supportsDevelopmentPrinter =>
      selectedSettingsType == 'Billing' || selectedSettingsType == 'Quotation';

  List<BluetoothPrinter> get _displayDevices {
    if (!_developerModeEnabled || !_supportsDevelopmentPrinter) {
      return devices;
    }
    return [
      BluetoothPrinter.development(),
      ...devices.where((printer) => !printer.isDevelopment),
    ];
  }

  /// True when editing a B2B Billing or PDF Sharing profile.
  bool get _isB2BSegment =>
      (selectedSettingsType == 'Billing' || _isPdfSharing) &&
      selectedSegment == 'B2B';

  String get _printerPrefsKey {
    switch (selectedSettingsType) {
      case 'Billing':
        return _isB2BSegment ? 'default_printer_b2b' : 'default_printer';
      case 'Quotation':
        return 'quotation_printer';
      case 'Barcode':
        return 'barcode_printer';
      case 'PDF Sharing':
        return 'share_pdf_no_printer';
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
      case 'PDF Sharing':
        return PdfShareSettings.paperPreferenceKey(isB2B: _isB2BSegment);
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
      case 'PDF Sharing':
        return 'share_pdf_no_font_style';
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
      case 'PDF Sharing':
        return PdfShareSettings.themePreferenceKey(isB2B: _isB2BSegment);
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
        case 'simplified_tax_invoice':
          return 'ZATCA Simplified Tax Invoice with teal accent header/footer, bilingual columns and totals';
        case 'centered_simplified_tax_invoice':
          return 'Simplified Tax Invoice with Arabic details on the left, a centered logo and English details on the right';
        case 'bilingual_centered_tax_invoice':
          return 'Bilingual centered Tax Invoice with Arabic details on the left, a centered logo and English details on the right';
        case 'boxed_bilingual_tax_invoice':
          return 'Boxed bilingual Tax Invoice with seller, buyer, invoice, items, bank and totals sections';
        case 'boxed_header_tax_invoice':
          return 'Boxed header Tax Invoice with seller, buyer, invoice, items, bank and totals sections';
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
    final isPdfSharing = settingsType == 'PDF Sharing';
    final isB2B = _isB2BSegment;
    final shareDocumentTheme = isPdfSharing
        ? resolveReceiptDocumentConfig(
            lookup: Provider.of<DocumentConfigProvider>(context, listen: false)
                .getCachedConfig,
            documentConfigType: 'Bill',
            hasReturns: false,
            paperSize: PdfShareSettings.defaultPaperSize,
          )?.activeTheme
        : null;
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
          !isPdfSharing &&
          _supportsDevelopmentPrinter &&
          await DevelopmentPrinterService.shouldUseForTarget(
            printerKey,
            preferences: prefs,
          );
      final shareProfile = isPdfSharing
          ? PdfShareSettings.resolve(
              prefs,
              isB2B: isB2B,
              documentTheme: shareDocumentTheme,
            )
          : null;
      final defaultPrinterJson =
          isPdfSharing ? null : prefs.getString(printerKey);
      final defaultPaperSize = settingsType == 'Barcode'
          ? null
          : shareProfile?.paperSize ?? prefs.getString(paperSizeKey);
      final defaultFontStyle = settingsType == 'Barcode' || isPdfSharing
          ? null
          : prefs.getString(fontStyleKey);
      final savedTheme = settingsType == 'Barcode'
          ? null
          : shareProfile?.theme ?? prefs.getString(themeKey);

      var paperSize = defaultPaperSize ??
          (isPdfSharing ? PdfShareSettings.defaultPaperSize : '80mm');
      if (paperSize == 'Thermal') {
        paperSize = '80mm';
        await prefs.setString(paperSizeKey, paperSize);
      }
      final validPaperSizes =
          isPdfSharing ? PdfShareSettings.paperSizes : paperSizes;
      if (!validPaperSizes.contains(paperSize)) {
        paperSize = isPdfSharing ? PdfShareSettings.defaultPaperSize : '80mm';
      }

      final fontStyle = fontStyles.contains(defaultFontStyle)
          ? defaultFontStyle!
          : 'Font A (Small & Sharp)';
      final themes = isPdfSharing || paperSize == 'A4' || paperSize == 'A5'
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
      final isPdfSharing = _isPdfSharing;
      setState(() {
        selectedPrinter = null;
        // Reset local state variables to defaults
        selectedPaperSize =
            isPdfSharing ? PdfShareSettings.defaultPaperSize : '80mm';
        selectedFontStyle = 'Font A (Small & Sharp)';
        selectedReceiptTheme = 'classic';
      });

      // Also clear current context keys
      final prefs = await SharedPreferences.getInstance();
      if (isPdfSharing) {
        await prefs.remove(_paperSizePrefsKey);
        await prefs.remove(_receiptThemePrefsKey);
      } else {
        await DevelopmentPrinterService.clearTargetSelection(
          _printerPrefsKey,
          preferences: prefs,
        );
      }
      if (selectedSettingsType == 'Barcode') {
        await prefs.remove(_printerPrefsKey);
      } else if (!isPdfSharing) {
        await prefs.remove(_printerPrefsKey);
        await prefs.remove(_paperSizePrefsKey);
        await prefs.remove(_fontStylePrefsKey);
        await prefs.remove(_receiptThemePrefsKey);
      }

      if (isPdfSharing) {
        await _loadSettings();
      }

      if (mounted) {
        showScaffold(
          context: context,
          message: isPdfSharing
              ? 'PDF Sharing settings reset to compatible defaults'
              : '$selectedSettingsType printer settings reset to default',
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
        _buildAdvancedSection(),
        SizedBox(height: gap),
        Expanded(
          child: BarcodeLayoutSettingsPanel(
            printerListWidget: _buildPrinterList(),
          ),
        ),
      ],
    );
  }

  /// Body for printer and PDF-sharing profiles — everything scrolls.
  Widget _buildDefaultBody() {
    final gap = printerSectionGap(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        SizedBox(height: gap),
        _buildTabToggle(),
        if (selectedSettingsType == 'Billing' || _isPdfSharing) ...[
          // Previously 4px on desktop — visually welded to the tab pills above
          // it. Match the page's normal section gap instead.
          SizedBox(height: gap),
          _buildSegmentToggle(),
        ],
        SizedBox(height: gap),
        if (_isPdfSharing)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _buildSettingsSection(),
            ),
          )
        else
          PrinterSettingsSplitLayout(
            settingsColumn: _buildSettingsSection(),
            printerColumn: _buildPrinterList(),
          ),
        if (selectedSettingsType == 'Billing') ...[
          SizedBox(height: gap),
          Consumer<DocumentConfigProvider>(
            builder: (context, provider, _) {
              final config = resolveReceiptDocumentConfig(
                lookup: provider.getCachedConfig,
                documentConfigType: 'Bill',
                hasReturns: false,
                paperSize: selectedPaperSize,
              );
              final themeName = _activeThemes.firstWhere(
                (theme) => theme['id'] == selectedReceiptTheme,
                orElse: () => {'name': selectedReceiptTheme},
              )['name']!;
              return ReceiptConfigurationWorkspace(
                config: config,
                paperSize: selectedPaperSize,
                themeName: themeName,
                themeId: selectedReceiptTheme,
                onResync: _resyncDocumentConfigurations,
                isResyncing: _isResyncingDocConfig,
              );
            },
          ),
        ],
        SizedBox(height: gap),
        _buildAdvancedSection(),
      ],
    );
  }

  /// Output settings for the profile currently selected in the tab/segment
  /// toggles. Paper size and theme share one card because they are one
  /// decision — what the printed document looks like.
  ///
  /// App-wide options live in [_buildAdvancedSection] instead, so nothing in
  /// this card can silently change another tab.
  Widget _buildSettingsSection() {
    final cardPadding = printerCardPadding(context);
    final isCompact = printerIsCompact(context);
    final fieldGap = isCompact ? 12.0 : 20.0;

    final paperField = PrinterDropdownField(
      label: 'Paper Size',
      value: _activePaperSizes.contains(selectedPaperSize)
          ? selectedPaperSize
          : (_isPdfSharing ? PdfShareSettings.defaultPaperSize : '80mm'),
      items: _activePaperSizes.map((String size) {
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
          final willBeThermal =
              newValue == '112mm' || newValue == '80mm' || newValue == '58mm';

          setState(() {
            selectedPaperSize = newValue;

            // Reset theme if crossing thermal↔standard boundary
            // and current theme doesn't exist in the new list
            if (wasThermal != willBeThermal) {
              final newThemes = _activeThemes;
              final themeExists =
                  newThemes.any((t) => t['id'] == selectedReceiptTheme);
              if (!themeExists) {
                selectedReceiptTheme = 'classic';
                _saveReceiptTheme('classic');
              }
            }
          });
          _saveDefaultPaperSize(newValue);
        }
      },
    );

    final themeField = !_usesReceiptSettings
        ? null
        : PrinterDropdownField(
            label: _isPdfSharing ? 'Template' : 'Theme',
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
          );

    Widget fields;
    if (themeField == null) {
      fields = paperField;
    } else {
      fields = Column(
        children: [
          paperField,
          SizedBox(height: fieldGap),
          themeField,
        ],
      );
    }

    return PrinterSettingsCard(
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.description_rounded,
            title: _isPdfSharing ? 'PDF Output' : 'Receipt Output',
            subtitle: _isPdfSharing
                ? 'Page size and template used for generated invoice files'
                : 'Paper size and visual layout for printed receipts',
          ),
          SizedBox(height: fieldGap),
          fields,
          if (themeField != null) ...[
            const SizedBox(height: 10),
            Text(
              _getThemeDescription(selectedReceiptTheme),
              // buildCustomStyle bakes in TextOverflow.ellipsis, which clips to
              // a single line unless maxLines is given explicitly.
              maxLines: 3,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.10,
                Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// App-wide print options, collapsed by default.
  ///
  /// These are deliberately kept out of [_buildSettingsSection] and labelled
  /// with their scope: they are stored once and affect every tab, so showing
  /// them as peers of the per-profile settings made them read as tab-local.
  Widget _buildAdvancedSection() {
    final gap = printerSectionGap(context);

    // Barcode has its own driver setting and PDF sharing never reaches a
    // Windows print job, so the driver control is irrelevant on those tabs.
    final showDriverSetting =
        !_isPdfSharing && selectedSettingsType != 'Barcode';

    // Print Margins only affects standard PDF (A4/A5) output. Barcode
    // stickers use their own Page Margin setting instead of this one.
    final isBarcodeTab = selectedSettingsType == 'Barcode';
    final marginsEnabled = !isBarcodeTab && _isStandardPdf;
    final String marginsDisabledNote = isBarcodeTab
        ? 'Barcode stickers use their own Page Margin setting instead.'
        : 'Only affects A4 and A5 print jobs. '
            'Switch the paper size to A4 or A5 to change it.';

    final String subtitle;
    if (isBarcodeTab) {
      subtitle = 'Barcode stickers keep their own Page Margin';
    } else if (showDriverSetting) {
      subtitle = 'PDF margins and printer driver behaviour';
    } else {
      subtitle = 'Shared PDF page margins';
    }

    return PrinterDisclosureCard(
      icon: Icons.tune_rounded,
      title: 'Advanced print options',
      subtitle: subtitle,
      scopeLabel: 'Applies to all tabs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonPrintMarginsCard(
            embedded: true,
            enabled: marginsEnabled,
            disabledNote: marginsDisabledNote,
          ),
          if (showDriverSetting) ...[
            SizedBox(height: gap),
            Divider(height: 1, color: Colors.grey.shade200),
            SizedBox(height: gap),
            CommonPrinterSettingsCard(
              embedded: true,
              enabled: _isStandardPdf,
              disabledNote: 'Only affects A4 and A5 print jobs. '
                  'Switch the paper size to A4 or A5 to change it.',
            ),
          ],
        ],
      ),
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
            _isPdfSharing ? Icons.picture_as_pdf_rounded : Icons.print_rounded,
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
                _isPdfSharing ? 'PDF Sharing Settings' : 'Printer Settings',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  isCompact ? FontSize.s18 : FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isPdfSharing
                    ? 'Configure invoice PDFs independently from physical printers'
                    : 'Configure printers, paper sizes and receipt themes',
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

    return PrinterSettingsCard(
      padding: cardPadding,
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildResyncButton(isCompact)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildClearButton(isCompact)),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                _buildResyncButton(isCompact),
                const SizedBox(width: 8),
                _buildClearButton(isCompact),
              ],
            ),
    );
  }

  Widget _buildResyncButton(bool isCompact) {
    return CustomRoundButtonWithIcon(
      fct: _isResyncingDocConfig ? () {} : _resyncDocumentConfigurations,
      title: _isResyncingDocConfig ? 'Resyncing…' : 'Resync',
      size: Size.zero,
      height: isCompact ? 36 : 40,
      width: isCompact ? double.infinity : 120,
      fontSize: isCompact ? 12 : 13,
      icon: const Icon(Icons.sync_rounded,
          size: 16, color: ColorManager.kPrimaryColor),
      boxColor: Colors.white,
      borderColor: ColorManager.kPrimaryColor,
      textColor: ColorManager.kPrimaryColor,
    );
  }

  Widget _buildClearButton(bool isCompact) {
    return CustomRoundButtonWithIcon(
      fct: clearDefaultPrinter,
      title: _isPdfSharing ? 'Reset' : 'Clear',
      size: Size.zero,
      height: isCompact ? 36 : 40,
      width: isCompact ? double.infinity : 100,
      fontSize: isCompact ? 12 : 13,
      icon: const Icon(Icons.restart_alt_rounded,
          size: 16, color: ColorManager.kButtonRed),
      boxColor: Colors.white,
      borderColor: ColorManager.kButtonRed,
      textColor: ColorManager.kButtonRed,
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

  /// B2C / B2B selector for Billing and PDF Sharing profiles.
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
      helperText: _isPdfSharing
          ? 'Choose the page size and PDF template for '
              '${selectedSegment == 'B2B' ? 'business (B2B)' : 'retail (B2C)'} '
              'invoice sharing. B2B uses the B2C sharing profile when left unconfigured.'
          : 'Configure a separate printer, paper size and theme for '
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
                : '${displayDevices.length} device${displayDevices.length == 1 ? '' : 's'} found',
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
              // A plain Column instead of a shrink-wrapped, non-scrolling
              // ListView: same layout, but Column supports intrinsic-height
              // measurement so this card can match the Receipt Output card's
              // height in PrinterSettingsSplitLayout. It never scrolled on its
              // own (NeverScrollableScrollPhysics) so nothing else changes.
              : Column(
                  // ListView stretched every item to the full cross-axis
                  // width; Column defaults to centering instead, so that has
                  // to be requested explicitly or every tile shrinks to its
                  // own content width.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int index = 0;
                        index < displayDevices.length;
                        index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _buildPrinterDeviceTile(
                        printer: displayDevices[index],
                        isSelected: selectedPrinter != null &&
                            _printerIdentity(selectedPrinter!) ==
                                _printerIdentity(displayDevices[index]),
                        isCompact: isCompact,
                      ),
                    ],
                  ],
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
