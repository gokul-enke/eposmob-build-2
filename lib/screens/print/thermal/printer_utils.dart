import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';

/// Utility functions for thermal printer operations
class ThermalPrinterUtils {
  final PrinterManager printerManager;

  // Bluetooth receipt data is mostly raster images and can be much larger
  // than a printer's input buffer. Sending it in paced chunks prevents cheap
  // thermal printers from dropping the tail of a receipt.
  static const int _bluetoothChunkSize = 1024;
  static const Duration _bluetoothChunkDelay = Duration(milliseconds: 15);
  static String? _connectedBluetoothAddress;

  ThermalPrinterUtils({PrinterManager? manager})
      : printerManager = manager ?? PrinterManager.instance;

  /// Sanitizes text for thermal printer compatibility
  /// Handles special characters differently for Arabic vs non-Arabic text
  String sanitizeText(String text, {bool isArabic = false}) {
    if (isArabic) {
      // For Arabic: only replace problematic special chars, preserve Arabic Unicode (U+0600-U+06FF)
      return text
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('‘', "'")
          .replaceAll('’', "'")
          .replaceAll('…', '...');
      // Keep Arabic text intact - no final regex cleanup
    } else {
      // For non-Arabic: use original strict sanitization
      return text
          // Replace em dash with regular hyphen
          .replaceAll('–', '-')
          .replaceAll('—', '-') // en dash as well
          // Replace other problematic Unicode characters
          .replaceAll('“', '"') // smart quotes to regular quotes
          .replaceAll('”', '"')
          .replaceAll('‘', "'") // smart apostrophes
          .replaceAll('’', "'")
          .replaceAll('…', '...') // ellipsis
          // Remove any remaining non-printable characters except basic punctuation
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    }
  }

  /// Load font type from SharedPreferences
  Future<PosFontType> loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  /// Connect to the specified printer
  Future<void> connectToPrinter(BluetoothPrinter selectedPrinter) async {
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
      final address = selectedPrinter.address!;
      if (printerManager.currentStatusBT == BTStatus.connected &&
          _connectedBluetoothAddress == address) {
        debugPrint('Reusing Bluetooth printer connection: $address');
        return;
      }

      // A different printer may still own the package's single Bluetooth
      // socket. Close it before connecting to the newly selected device.
      if (printerManager.currentStatusBT == BTStatus.connected) {
        await printerManager.disconnect(type: PrinterType.bluetooth);
      }

      final connected = await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: selectedPrinter.deviceName ?? 'Unknown',
          address: address,
          isBle: false,
        ),
      );
      if (!connected) {
        _connectedBluetoothAddress = null;
        throw Exception('Could not connect to Bluetooth printer');
      }
      _connectedBluetoothAddress = address;
    } else if (selectedPrinter.typePrinter == PrinterType.network) {
      final address = selectedPrinter.address?.trim();
      if (address == null || address.isEmpty) {
        throw Exception('Network printer address is null');
      }
      final connected = await printerManager.connect(
        type: PrinterType.network,
        model: TcpPrinterInput(
          ipAddress: address,
          port: int.tryParse(selectedPrinter.port ?? '') ?? 9100,
        ),
      );
      if (!connected) {
        throw Exception('Could not connect to network printer');
      }
    }
  }

  /// Sends a complete print job and fails if the printer package rejects any
  /// part of it. Bluetooth is deliberately paced because `send` only confirms
  /// that bytes reached Android's socket, not that the printer consumed them.
  Future<void> sendPrintJob(
    BluetoothPrinter selectedPrinter,
    List<int> bytes,
  ) async {
    if (selectedPrinter.typePrinter != PrinterType.bluetooth) {
      final sent = await printerManager.send(
        type: selectedPrinter.typePrinter,
        bytes: bytes,
      );
      if (!sent) {
        throw Exception('Printer rejected the print job');
      }
      return;
    }

    for (var offset = 0; offset < bytes.length; offset += _bluetoothChunkSize) {
      final end = (offset + _bluetoothChunkSize < bytes.length)
          ? offset + _bluetoothChunkSize
          : bytes.length;
      final sent = await printerManager.send(
        type: PrinterType.bluetooth,
        bytes: bytes.sublist(offset, end),
      );
      if (!sent) {
        _connectedBluetoothAddress = null;
        throw Exception(
          'Bluetooth printer disconnected while sending the print job',
        );
      }
      if (end < bytes.length) {
        await Future<void>.delayed(_bluetoothChunkDelay);
      }
    }
  }

  /// Disconnect from the specified printer
  Future<void> disconnectPrinter(BluetoothPrinter selectedPrinter) async {
    // Keep Bluetooth connected after a job. The printer package reports an
    // intentional socket close as "Bluetooth connection lost", and closing as
    // soon as `send` returns can truncate bytes still buffered by the printer.
    if (selectedPrinter.typePrinter == PrinterType.bluetooth) {
      return;
    }

    try {
      await printerManager.disconnect(type: selectedPrinter.typePrinter);
    } catch (e) {
      // Handle disconnection error silently
    }
  }

  /// Debug print template settings
  void debugPrintTemplateSettings(Map<String, DisplayOption>? displayConfig) {
    if (displayConfig == null) {
      debugPrint("ERROR: Display configuration is null!");
      return;
    }

    debugPrint("Current display settings (from Bill config):");
    displayConfig.forEach((key, value) {
      debugPrint("- $key: visible=${value.visible}, value=${value.value}");
    });
  }
}
