import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashDrawerService {
  const CashDrawerService();

  /// Open cash drawer via thermal printer
  /// If no printer is configured and in debug mode, simulates the action
  Future<bool> openDrawer(BuildContext context,
      {bool simulateIfNoPrinter = false}) async {
    BluetoothPrinter? printer;
    final printerUtils = ThermalPrinterUtils();

    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPrinterJson = prefs.getString('default_printer');

      // No printer configured
      if (defaultPrinterJson == null || defaultPrinterJson.isEmpty) {
        // In debug mode or if explicitly requested, simulate the drawer open
        if (kDebugMode || simulateIfNoPrinter) {
          debugPrint(
              '[CashDrawerService] No printer configured. Simulating drawer open...');

          // Show loading briefly to simulate the action
          await Future.delayed(const Duration(seconds: 1));

          if (context.mounted) {
            showScaffold(
              context: context,
              message: 'Cash drawer opened (simulated)',
            );
          }
          return true;
        }

        // Production mode without printer
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'No default printer configured',
          );
        }
        return false;
      }

      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
      printer = BluetoothPrinter(
        deviceName: printerData['deviceName'],
        address: printerData['address'],
        vendorId: printerData['vendorId'],
        productId: printerData['productId'],
        typePrinter: PrinterType.values.firstWhere(
          (type) => type.toString() == printerData['typePrinter'],
          orElse: () => PrinterType.bluetooth,
        ),
      );

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final bytes = <int>[]..addAll(generator.drawer());

      await printerUtils.connectToPrinter(printer);
      await printerUtils.sendPrintJob(printer, bytes);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Cash drawer opened successfully',
        );
      }
      return true;
    } catch (error) {
      debugPrint('[CashDrawerService] Failed to open cash drawer: $error');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Unable to open cash drawer',
        );
      }
      return false;
    } finally {
      if (printer != null) {
        await printerUtils.disconnectPrinter(printer);
      }
    }
  }
}
