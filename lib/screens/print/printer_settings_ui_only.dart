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

class _PrinterSettingsState extends State<PrinterSettings>
    with TickerProviderStateMixin {
  BluetoothPrinter? selectedPrinter;
  bool isLoading = true;
  String selectedPaperSize = '80mm';
  String selectedFontStyle = 'Font A (Small & Sharp)';

  // Animation controllers
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Printer scanning variables
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  bool _isScanning = false;

  // List of available paper sizes with icons
  final List<Map<String, dynamic>> paperSizes = [
    {'value': '80mm', 'label': '80mm (Standard)', 'icon': Icons.receipt_long},
    {'value': '58mm', 'label': '58mm (Compact)', 'icon': Icons.receipt},
    {'value': 'A5', 'label': 'A5 (Medium)', 'icon': Icons.description},
    {'value': 'A4', 'label': 'A4 (Large)', 'icon': Icons.article},
  ];

  // List of available font styles with descriptions
  final List<Map<String, dynamic>> fontStyles = [
    {
      'value': 'Font A (Small & Sharp)',
      'label': 'Font A',
      'description': 'Small & Sharp - Perfect for receipts',
      'icon': Icons.text_fields
    },
    {
      'value': 'Font B (Default)',
      'label': 'Font B',
      'description': 'Default - Standard readable font',
      'icon': Icons.font_download
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSettings();
    _addDummyPrinters(); // Add dummy printers for demo
  }

  void _initAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimationController.forward();
    _slideAnimationController.forward();
  }

  void _addDummyPrinters() {
    // Add some dummy printers for demo purposes
    devices.addAll([
      BluetoothPrinter(
        deviceName: "EPSON TM-T88VI",
        address: "00:11:22:33:44:55",
        typePrinter: PrinterType.bluetooth.toString(),
        isConnected: true,
      ),
      BluetoothPrinter(
        deviceName: "Star TSP650II",
        address: "AA:BB:CC:DD:EE:FF",
        typePrinter: PrinterType.bluetooth.toString(),
        isConnected: false,
      ),
      BluetoothPrinter(
        deviceName: "Citizen CT-S310II",
        vendorId: "1234",
        productId: "5678",
        typePrinter: PrinterType.usb.toString(),
        isConnected: false,
      ),
      BluetoothPrinter(
        deviceName: "Bixolon SRP-330II",
        address: "12:34:56:78:90:AB",
        typePrinter: PrinterType.bluetooth.toString(),
        isConnected: false,
      ),
    ]);

    // Set first printer as selected for demo
    if (devices.isNotEmpty) {
      selectedPrinter = devices.first;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPermissions();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  // [Keep all the existing methods for permissions, scanning, etc. - unchanged]
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
      // Don't clear devices for demo - keep dummy data
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
          // Check if device already exists before adding
          bool exists = devices.any((d) => d.address == device.address);
          if (!exists) {
            devices.add(printer);
          }
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
          bool exists = devices.any((d) => 
            d.vendorId == device.vendorId && d.productId == device.productId);
          if (!exists) {
            devices.add(printer);
          }
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

  // [Keep all other existing methods unchanged - _saveDefaultPrinter, _loadSettings, etc.]
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
        if (defaultPaperSize == 'Thermal') {
          selectedPaperSize = '80mm';
          _saveDefaultPaperSize('80mm');
        } else {
          selectedPaperSize = defaultPaperSize;
        }
      });
    } else {
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
      final String? emailRemember = prefs.getString('emailRemember');
      final String? passwordRemember = prefs.getString('passwordRemember');
      final bool? rememberMe = prefs.getBool('remember_me');

      await prefs.clear();

      if (rememberMe == true) {
        await prefs.setBool('remember_me', true);
        if (emailRemember != null) {
          await prefs.setString('emailRemember', emailRemember);
        }
        if (passwordRemember != null) {
          await prefs.setString('passwordRemember', passwordRemember);
        }
      }

      await clearAllHiveData();

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.logout();

      if (mounted) {
        showScaffold(
          context: context,
          message: "Local storage cleared successfully",
        );

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
      PosFontType fontType = selectedFontStyle.contains('Font A')
          ? PosFontType.fontA
          : PosFontType.fontB;

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
      ];

      await _printSampleReceipt(
        selectedPrinter!,
        dummyCartItems,
        fontType,
        '1205.00',
        '45.00',
        DateTime.now().toIso8601String(),
        'DEMO-${DateTime.now().millisecondsSinceEpoch}',
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

  // [Keep all existing printing methods unchanged]
  Future<void> _printSampleReceipt(
    BluetoothPrinter printer,
    List<Map<String, dynamic>> cartItems,
    PosFontType fontType,
    String formattedTotal,
    String savedTotal,
    String orderDate,
    String orderNumber,
  ) async {
    // Implementation remains the same as in your original code
    // [Keep the full implementation]
  }

  Future<void> _connectToPrinter(BluetoothPrinter selectedPrinter) async {
    // Keep existing implementation
  }

  Future<void> _disconnectPrinter(BluetoothPrinter selectedPrinter) async {
    // Keep existing implementation
  }

  Future<void> clearAllHiveData() async {
    // Keep existing implementation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isLoading
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: ColorManager.kPrimaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading Printer Settings...',
                      style: TextStyle(
                        color: ColorManager.kTitleTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Header
                      _buildEnhancedHeader(),
                      const SizedBox(height: 24),

                      // Current Default Printer Section
                      if (selectedPrinter != null) ...[
                        _buildCurrentPrinterSection(),
                        const SizedBox(height: 20),
                      ],

                      // Paper Size & Font Style Row
                      Row(
                        children: [
                          Expanded(child: _buildPaperSizeSection()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildFontStyleSection()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sample Print Section
                      _buildSamplePrintSection(),
                      const SizedBox(height: 20),

                      // Available Printers Section
                      _buildAvailablePrintersSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ColorManager.kPrimaryColor, Color(0xFF667EEA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ColorManager.kPrimaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Printer Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configure your POS printing preferences',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  onTap: clearLocalStorageAndLogout,
                  icon: Icons.storage,
                  title: 'Clear Storage',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  onTap: clearDefaultPrinter,
                  icon: Icons.print_disabled_rounded,
                  title: 'Clear Printer',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPrinterSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Active Printer',
                style: TextStyle(
                  color: ColorManager.kTitleTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CONNECTED',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.print,
                    color: ColorManager.kPrimaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedPrinter!.deviceName ?? 'Unknown Printer',
                        style: const TextStyle(
                          color: ColorManager.kTitleTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedPrinter!.typePrinter.contains('bluetooth')
                            ? 'Bluetooth • ${selectedPrinter!.address}'
                            : 'USB • ID: ${selectedPrinter!.vendorId}',
                        style: const TextStyle(
                          color: ColorManager.kGreyColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.signal_cellular_4_bar,
                  color: Colors.green,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSizeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Paper Size',
                style: TextStyle(
                  color: ColorManager.kTitleTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButton<String>(
              value: selectedPaperSize,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: ColorManager.kPrimaryColor),
              items: paperSizes.map((size) {
                return DropdownMenuItem<String>(
                  value: size['value'],
                  child: Row(
                    children: [
                      Icon(size['icon'], size: 20, color: ColorManager.kPrimaryColor),
                      const SizedBox(width: 12),
                      Text(
                        size['label'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
    );
  }

  Widget _buildFontStyleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.font_download,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Font Style',
                style: TextStyle(
                  color: ColorManager.kTitleTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButton<String>(
              value: selectedFontStyle,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: ColorManager.kPrimaryColor),
              items: fontStyles.map((style) {
                return DropdownMenuItem<String>(
                  value: style['value'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(style['icon'], size: 20, color: ColorManager.kPrimaryColor),
                          const SizedBox(width: 12),
                          Text(
                            style['label'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: Text(
                          style['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
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
    );
  }

  Widget _buildSamplePrintSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withOpacity(0.1), Colors.red.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Your Settings',
                      style: TextStyle(
                        color: ColorManager.kTitleTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Print a sample receipt with dummy data',
                      style: TextStyle(
                        color: ColorManager.kGreyColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _printSample,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.print, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Print Sample',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sample Receipt Preview:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Premium Coffee Beans - ₹400.00 x 2\n• Organic Green Tea - ₹225.00 x 1\n• Fresh Milk 1L - ₹60.00 x 3',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Total: ₹1,205.00',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePrintersSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ColorManager.kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.devices,
                      color: ColorManager.kPrimaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Printers',
                        style: TextStyle(
                          color: ColorManager.kTitleTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${devices.length} devices discovered',
                        style: const TextStyle(
                          color: ColorManager.kGreyColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: _isScanning ? null : _checkPermissions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: _isScanning
                        ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!])
                        : const LinearGradient(
                            colors: [ColorManager.kPrimaryColor, Color(0xFF667EEA)],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_isScanning ? Colors.grey : ColorManager.kPrimaryColor)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isScanning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        const Icon(Icons.search, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _isScanning ? 'Scanning...' : 'Scan Devices',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Printers Grid
          devices.isEmpty
              ? _buildEmptyPrintersState()
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final printer = devices[index];
                    final isSelected = selectedPrinter?.deviceName == printer.deviceName &&
                        selectedPrinter?.address == printer.address;

                    return _buildPrinterCard(printer, isSelected);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrintersState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.print_disabled,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Printers Found',
            style: TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Scan Devices" to search for nearby printers',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard(BluetoothPrinter printer, bool isSelected) {
    return GestureDetector(
      onTap: () => selectPrinter(printer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? ColorManager.kPrimaryColor.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ColorManager.kPrimaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorManager.kPrimaryColor
                        : ColorManager.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    printer.typePrinter.contains('bluetooth') ? Icons.bluetooth : Icons.usb,
                    color: isSelected ? Colors.white : ColorManager.kPrimaryColor,
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              printer.deviceName ?? 'Unknown Device',
              style: TextStyle(
                color: ColorManager.kTitleTextColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              printer.typePrinter.contains('bluetooth')
                  ? 'Bluetooth'
                  : 'USB Connection',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? ColorManager.kPrimaryColor : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? ColorManager.kPrimaryColor : Colors.grey[300]!,
                ),
              ),
              child: Text(
                isSelected ? 'SELECTED' : 'SELECT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : ColorManager.kPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}