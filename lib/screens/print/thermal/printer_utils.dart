import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';

/// Utility functions for thermal printer operations
class ThermalPrinterUtils {
  final PrinterManager printerManager;

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

  /// Disconnect from the specified printer
  Future<void> disconnectPrinter(BluetoothPrinter selectedPrinter) async {
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
