import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashDrawerService {
  const CashDrawerService();

  /// Open cash drawer via thermal printer
  /// If no printer is configured and in debug mode, simulates the action
  Future<bool> openDrawer(BuildContext context, {bool simulateIfNoPrinter = false}) async {
    BluetoothPrinter? printer;

    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultPrinterJson = prefs.getString('default_printer');

      // No printer configured
      if (defaultPrinterJson == null || defaultPrinterJson.isEmpty) {
        // In debug mode or if explicitly requested, simulate the drawer open
        if (kDebugMode || simulateIfNoPrinter) {
          debugPrint('[CashDrawerService] No printer configured. Simulating drawer open...');
          
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

      final printerManager = PrinterManager.instance;
      await _connectToPrinter(printerManager, printer);
      await printerManager.send(type: printer.typePrinter, bytes: bytes);

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
        await _disconnectPrinter(PrinterManager.instance, printer);
      }
    }
  }

  Future<void> _connectToPrinter(
    PrinterManager printerManager,
    BluetoothPrinter printer,
  ) async {
    if (printer.typePrinter == PrinterType.usb) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: printer.deviceName ?? 'Unknown',
          productId: printer.productId,
          vendorId: printer.vendorId,
        ),
      );
      return;
    }

    if (printer.typePrinter == PrinterType.bluetooth) {
      final address = printer.address;
      if (address == null || address.isEmpty) {
        throw Exception('Bluetooth printer address is missing');
      }

      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: printer.deviceName ?? 'Unknown',
          address: address,
          isBle: false,
        ),
      );
      return;
    }

    throw Exception('Unsupported printer type: ${printer.typePrinter}');
  }

  Future<void> _disconnectPrinter(
    PrinterManager printerManager,
    BluetoothPrinter printer,
  ) async {
    try {
      await printerManager.disconnect(type: printer.typePrinter);
    } catch (error) {
      debugPrint('[CashDrawerService] Failed to disconnect printer: $error');
    }
  }
}