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
  
  // Printer scanning variables
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  bool _isScanning = false;

  // List of available paper sizes
  final List<String> paperSizes = ['80mm', '58mm', 'A5', 'A4'];

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
                                fct: () => _isScanning ? null : _checkPermissions(),
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
                                          color: ColorManager.kGreyColor.withOpacity(0.8),
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
                                    final isSelected = selectedPrinter?.deviceName == printer.deviceName &&
                                                      selectedPrinter?.address == printer.address;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
                                            : Border.all(color: Colors.grey[300]!),
                                        color: isSelected 
                                            ? ColorManager.kPrimaryColor.withOpacity(0.1)
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
                                          printer.deviceName ?? 'Unknown device',
                                          style: TextStyle(
                                            color: ColorManager.kTitleTextColor,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Text(
                                          printer.address ?? printer.typePrinter,
                                          style: const TextStyle(
                                            color: ColorManager.kGreyColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        trailing: CustomRoundButton(
                                          fct: () => selectPrinter(printer),
                                          title: isSelected ? 'Selected' : 'Select',
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
