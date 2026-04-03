import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:pos_machine/screens/product/widgets/confirm_barcode_print_modal.dart';
import 'package:intl/intl.dart';

class BarcodePrinterService {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();
  final PrinterManager _printerManager = PrinterManager.instance;

  Future<BluetoothPrinter?> _getDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson = prefs.getString('default_printer');
    if (defaultPrinterJson == null) return null;

    final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
    return BluetoothPrinter(
      deviceName: printerData['deviceName'],
      address: printerData['address'],
      vendorId: printerData['vendorId'],
      productId: printerData['productId'],
      typePrinter: PrinterType.values.firstWhere(
        (e) => e.toString() == printerData['typePrinter'],
      ),
    );
  }

  Future<void> printBarcodes({
    required BuildContext context,
    required List<BarcodePrintItem> printItems,
    String stickerSize = '50x25',
  }) async {
    if (printItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stocks selected to print.')),
      );
      return;
    }

    final printer = await _getDefaultPrinter();
    if (printer == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No default printer selected. Please set one in Printer Settings.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connecting to ${printer.deviceName}...')),
      );
    }

    try {
      await _printerUtils.connectToPrinter(printer);
      final profile = await CapabilityProfile.load();
      final prefs = await SharedPreferences.getInstance();
      String paperSizeStr = prefs.getString('default_paper_size') ?? '80mm';
      PaperSize paperSize = (paperSizeStr == '58mm') ? PaperSize.mm58 : PaperSize.mm80;

      final generator = Generator(paperSize, profile);
      final fontType = await _printerUtils.loadFontType();

      List<int> bytes = [];

      int barcodeHeight = 50;
      if (stickerSize == '40x20') {
        barcodeHeight = 30; // Shorter barcode to leave more space
      } else if (stickerSize == '50x25') {
        barcodeHeight = 40; // Slightly shorter
      } else if (stickerSize == '91x24mm') {
        barcodeHeight = 40;
      }

      for (var item in printItems) {
        for (int i = 0; i < item.quantity; i++) {
          final stock = item.stock;

          // 1. Product Name
          if (stock.productName != null && stock.productName!.isNotEmpty) {
            bytes += generator.text(
              stock.productName!,
              styles: PosStyles(align: PosAlign.center, bold: true, fontType: fontType),
            );
          }

          // 2. Price
          final priceToShow = stock.retailPrice ?? stock.mrp ?? 'N/A';
          bytes += generator.text(
            "SR.$priceToShow",
            styles: PosStyles(align: PosAlign.center, bold: true, fontType: fontType),
          );

          // 3 & 4. Barcode and Barcode Number below it
          if (stock.barCode != null && stock.barCode!.isNotEmpty) {
            String cleanBarcode = stock.barCode!.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
            if (cleanBarcode.isNotEmpty) {
              List<String> code39Data = cleanBarcode.split('');
              bytes += generator.barcode(
                Barcode.code39(code39Data),
                height: barcodeHeight,
                width: 1,
                textPos: BarcodeText.none,
                align: PosAlign.center,
              );
              bytes += generator.text(
                stock.barCode!,
                styles: PosStyles(align: PosAlign.center, fontType: fontType),
              );
            } else {
              bytes += generator.text(
                stock.barCode!,
                styles: PosStyles(align: PosAlign.center, fontType: fontType),
              );
            }
          }

          // 5. MFG/EXP Date (e.g., P.02/26-E.02/28)
          String dateLine = "";
          if (item.mfgDate != null) {
            dateLine += "P.${DateFormat('MM/yy').format(item.mfgDate!)}";
          }
          if (item.expDate != null) {
            if (dateLine.isNotEmpty) dateLine += "-";
            dateLine += "E.${DateFormat('MM/yy').format(item.expDate!)}";
          }
          
          if (dateLine.isNotEmpty) {
            bytes += generator.text(
              dateLine,
              styles: PosStyles(align: PosAlign.center, fontType: fontType, bold: true),
            );
          }

          // Blank lines between stickers
          bytes += generator.emptyLines(1);
        }
      }

      bytes += generator.cut();

      await _printerManager.send(type: printer.typePrinter, bytes: bytes);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully sent print job to printer')),
        );
      }
    } catch (e) {
      debugPrint("Barcode printing error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print: $e')),
        );
      }
    } finally {
      await _printerUtils.disconnectPrinter(printer);
    }
  }
}
