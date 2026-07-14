import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerVoucherThermalPrinter {
  final BuildContext context;

  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Text size variables for consistent sizing
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  CustomerVoucherThermalPrinter(this.context);

  String _sanitizeTextForThermalPrinter(String text) {
    return text
        // Replace em dash with regular hyphen
        .replaceAll('–', '-')
        .replaceAll('—', '-') // en dash as well
        // Replace other problematic Unicode characters
        .replaceAll('"', '"') // smart quotes to regular quotes
        .replaceAll('"', '"')
        .replaceAll(''', "'") // smart apostrophes
        .replaceAll(''', "'")
        .replaceAll('…', '...') // ellipsis
        // Remove any remaining non-printable characters except basic punctuation
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  // Load font type from SharedPreferences
  Future<PosFontType> _loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  Future<Widget> printCustomerVoucher({
    required BluetoothPrinter? selectedPrinter,
    required CustomerVoucher voucher,
    required String selectedPaperSize,
    required DocumentConfig? voucherDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
  }) async {
    debugPrint("===== THERMAL PRINTING DEBUG - CUSTOMER VOUCHER =====");

    // Ensure voucherDocumentConfig is loaded before printing
    if (voucherDocumentConfig == null) {
      debugPrint("ERROR: Voucher document configuration not loaded yet.");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Document configurations not loaded. Please wait.",
        );
      }
      return const SizedBox.shrink();
    }

    debugPrint("Printing voucher with thermal printer:");
    debugPrint(
        "Printer: ${selectedPrinter?.deviceName} (${selectedPrinter?.typePrinter})");
    debugPrint("Paper size: $selectedPaperSize");

    try {
      if (selectedPrinter == null) {
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Please select a printer',
          );
        }
        return const SizedBox.shrink();
      }

      // Load the selected font type from preferences
      final selectedFontType = await _loadFontType();
      debugPrint(
          "Using font type: ${selectedFontType == PosFontType.fontA ? 'Font A' : 'Font B'}");

      // Generate receipt
      final profile = await CapabilityProfile.load();

      // Select appropriate paper size based on selection
      PaperSize paperSize;
      if (selectedPaperSize == '80mm') {
        paperSize = PaperSize.mm80;
        debugPrint("Using 80mm paper size configuration");
      } else if (selectedPaperSize == '58mm') {
        paperSize = PaperSize.mm58;
        debugPrint("Using 58mm paper size configuration");
      } else if (selectedPaperSize == '112mm') {
        paperSize = PaperSize.mm80;
        debugPrint("Using 112mm paper size configuration (mm80 ESC/POS mode)");
      } else {
        // Default to 80mm for any other value
        paperSize = PaperSize.mm80;
        debugPrint("Using default 80mm paper size configuration");
      }

      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      debugPrint("Starting to build voucher sections...");

      debugPrint("Building header...");
      // Header
      if (voucherDocumentConfig.header != null &&
          voucherDocumentConfig.header!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.header!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeMedium,
            width: textSizeMedium,
            bold: true,
            fontType: selectedFontType,
          ),
        );
      }
      debugPrint("Header built successfully");

      debugPrint("Building subheader...");
      // Subheader
      if (voucherDocumentConfig.subheader != null &&
          voucherDocumentConfig.subheader!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.subheader!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            bold: false,
            fontType: selectedFontType,
          ),
        );
      }
      debugPrint("Subheader built successfully");

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Voucher Details
      bytes += generator.text(
        'Voucher #: ${voucher.voucherNumber}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          bold: true,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.text(
        'Date: ${voucher.voucherDate}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.text(
        'Due Date: ${voucher.dueDate}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Customer Information
      bytes += generator.text(
        'Customer Details',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          bold: true,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.text(
        'Name: ${voucher.customer.user.name}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.text(
        'Phone: ${voucher.customer.user.phone}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Items Table Header
      bytes += generator.row([
        PosColumn(
          text: 'Item',
          width: 6,
          styles: PosStyles(
            align: PosAlign.left,
            height: textSizeSmall,
            bold: true,
            fontType: selectedFontType,
          ),
        ),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            bold: true,
            fontType: selectedFontType,
          ),
        ),
        PosColumn(
          text: 'Amount',
          width: 4,
          styles: PosStyles(
            align: PosAlign.right,
            height: textSizeSmall,
            bold: true,
            fontType: selectedFontType,
          ),
        ),
      ]);

      // Items
      for (var item in voucher.items) {
        bytes += generator.row([
          PosColumn(
            text: item.itemName,
            width: 6,
            styles: PosStyles(
              align: PosAlign.left,
              height: textSizeSmall,
              fontType: selectedFontType,
            ),
          ),
          PosColumn(
            text: item.quantity,
            width: 2,
            styles: PosStyles(
              align: PosAlign.center,
              height: textSizeSmall,
              fontType: selectedFontType,
            ),
          ),
          PosColumn(
            text: item.totalAmount,
            width: 4,
            styles: PosStyles(
              align: PosAlign.right,
              height: textSizeSmall,
              fontType: selectedFontType,
            ),
          ),
        ]);
      }

      bytes += generator.hr();

      // Total
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 8,
          styles: PosStyles(
            align: PosAlign.left,
            height: textSizeMedium,
            bold: true,
            fontType: selectedFontType,
          ),
        ),
        PosColumn(
          text: voucher.amount,
          width: 4,
          styles: PosStyles(
            align: PosAlign.right,
            height: textSizeMedium,
            bold: true,
            fontType: selectedFontType,
          ),
        ),
      ]);

      bytes += generator.hr();

      // Status and Payment Method
      bytes += generator.text(
        'Status: ${voucher.status.toUpperCase()}',
        styles: PosStyles(
          align: PosAlign.center,
          height: textSizeSmall,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.text(
        'Payment: ${voucher.paymentMethod.isNotEmpty ? voucher.paymentMethod : 'N/A'}',
        styles: PosStyles(
          align: PosAlign.center,
          height: textSizeSmall,
          fontType: selectedFontType,
        ),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Terms
      if (voucherDocumentConfig.terms != null &&
          voucherDocumentConfig.terms!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.terms!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            fontType: selectedFontType,
          ),
        );
        bytes += generator.emptyLines(1);
      }

      // Footer
      if (voucherDocumentConfig.footer != null &&
          voucherDocumentConfig.footer!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.footer!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            fontType: selectedFontType,
          ),
        );
        bytes += generator.emptyLines(1);
      }

      bytes += generator.cut();

      // Print
      await _printBytes(selectedPrinter, bytes);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Customer Voucher printed successfully',
        );
      }
    } catch (e) {
      debugPrint('Error printing customer voucher: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error printing: $e',
        );
      }
    }

    return const SizedBox.shrink();
  }

  Future<void> _printBytes(BluetoothPrinter printer, List<int> bytes) async {
    final printerUtils = ThermalPrinterUtils();
    try {
      await printerUtils.connectToPrinter(printer);
      await printerUtils.sendPrintJob(printer, bytes);
      debugPrint("Print job sent successfully");
    } catch (e) {
      debugPrint('Error in _printBytes: $e');
      rethrow;
    } finally {
      await printerUtils.disconnectPrinter(printer);
    }
  }
}
