import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _loadDefaultPrinter();
  }

  Future<void> _loadDefaultPrinter() async {
    setState(() {
      isLoading = true;
    });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BuildBoxShadowContainer(
        circleRadius: 16,
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shadowColor: ColorManager.shadowColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              'Default Printer Settings',
                              style: TextStyle(
                                color: ColorManager.kTitleTextColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        CustomRoundButton(
                          fct: () => {
                            selectedPrinter != null ? clearDefaultPrinter : null
                          },
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
                    const SizedBox(height: 8),
                    const Text(
                      'Manage your default printer settings here',
                      style: TextStyle(
                        color: ColorManager.kGreyColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    elevation: 2,
                    shadowColor: ColorManager.shadowColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Default Printer',
                            style: TextStyle(
                              color: ColorManager.kTitleTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          selectedPrinter != null
                              ? Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                                color: ColorManager
                                                    .kTitleTextColor,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              selectedPrinter!.address ??
                                                  'No address',
                                              style: const TextStyle(
                                                color: ColorManager.kGreyColor,
                                                fontSize: 14,
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
                                )
                              : const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Text(
                                      'No default printer set',
                                      style: TextStyle(
                                        color: ColorManager.kGreyColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
