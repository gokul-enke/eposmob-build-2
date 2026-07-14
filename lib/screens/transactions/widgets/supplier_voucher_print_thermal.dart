import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/supplier_voucher.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupplierVoucherThermalPrinter {
  final BuildContext context;

  static const PosFontType defaultFontType = PosFontType.fontB;
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  SupplierVoucherThermalPrinter(this.context);

  Future<PosFontType> _loadFontType() async {
    final prefs = await SharedPreferences.getInstance();
    final fontStyle =
        prefs.getString('default_font_style') ?? 'Font B (Default)';
    return fontStyle.contains('Font A') ? PosFontType.fontA : PosFontType.fontB;
  }

  Future<void> printSupplierVoucher({
    required BluetoothPrinter selectedPrinter,
    required SupplierVoucher voucher,
    required String selectedPaperSize,
    required DocumentConfig? voucherDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
  }) async {
    debugPrint("===== THERMAL PRINTER - SUPPLIER VOUCHER DEBUG INFO =====");
    debugPrint("Voucher Number: ${voucher.voucherNumber}");
    debugPrint("Supplier: ${voucher.supplier.name}");
    debugPrint("Amount: ${voucher.amount}");
    debugPrint("===== END THERMAL PRINTER DEBUG INFO =====");

    try {
      final fontType = await _loadFontType();
      final profile = await CapabilityProfile.load();

      // Select appropriate paper size
      PaperSize paperSize;
      if (selectedPaperSize == '80mm') {
        paperSize = PaperSize.mm80;
      } else if (selectedPaperSize == '58mm') {
        paperSize = PaperSize.mm58;
      } else if (selectedPaperSize == '112mm') {
        paperSize = PaperSize.mm80;
      } else {
        paperSize = PaperSize.mm80;
      }

      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // Header
      if (voucherDocumentConfig?.header != null &&
          voucherDocumentConfig!.header!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.header!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeMedium,
            width: textSizeMedium,
            bold: true,
            fontType: fontType,
          ),
        );
      }

      // Subheader
      if (voucherDocumentConfig?.subheader != null &&
          voucherDocumentConfig!.subheader!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.subheader!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            bold: false,
            fontType: fontType,
          ),
        );
      }

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Voucher Details
      bytes += generator.text(
        'Voucher #: ${voucher.voucherNumber}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          bold: true,
          fontType: fontType,
        ),
      );

      bytes += generator.text(
        'Date: ${voucher.voucherDate}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: fontType,
        ),
      );

      bytes += generator.text(
        'Due Date: ${voucher.dueDate}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: fontType,
        ),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Supplier Information
      bytes += generator.text(
        'Supplier Details',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          bold: true,
          fontType: fontType,
        ),
      );

      bytes += generator.text(
        'Name: ${voucher.supplier.name}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: fontType,
        ),
      );

      bytes += generator.text(
        'Phone: ${voucher.supplier.phone}',
        styles: PosStyles(
          align: PosAlign.left,
          height: textSizeSmall,
          fontType: fontType,
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
            fontType: fontType,
          ),
        ),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            bold: true,
            fontType: fontType,
          ),
        ),
        PosColumn(
          text: 'Amount',
          width: 4,
          styles: PosStyles(
            align: PosAlign.right,
            height: textSizeSmall,
            bold: true,
            fontType: fontType,
          ),
        ),
      ]);

      bytes += generator.hr();

      // Items
      for (var item in voucher.items) {
        bytes += generator.row([
          PosColumn(
            text: item.itemName.length > 15
                ? '${item.itemName.substring(0, 15)}...'
                : item.itemName,
            width: 6,
            styles: PosStyles(
              align: PosAlign.left,
              height: textSizeSmall,
              fontType: fontType,
            ),
          ),
          PosColumn(
            text: item.quantity,
            width: 2,
            styles: PosStyles(
              align: PosAlign.center,
              height: textSizeSmall,
              fontType: fontType,
            ),
          ),
          PosColumn(
            text: item.totalAmount,
            width: 4,
            styles: PosStyles(
              align: PosAlign.right,
              height: textSizeSmall,
              fontType: fontType,
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
            fontType: fontType,
          ),
        ),
        PosColumn(
          text: voucher.amount,
          width: 4,
          styles: PosStyles(
            align: PosAlign.right,
            height: textSizeMedium,
            bold: true,
            fontType: fontType,
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
          fontType: fontType,
        ),
      );

      bytes += generator.text(
        'Payment: ${voucher.paymentMethod.isNotEmpty ? voucher.paymentMethod : 'N/A'}',
        styles: PosStyles(
          align: PosAlign.center,
          height: textSizeSmall,
          fontType: fontType,
        ),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.hr();

      // Terms
      if (voucherDocumentConfig?.terms != null &&
          voucherDocumentConfig!.terms!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.terms!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            fontType: fontType,
          ),
        );
        bytes += generator.emptyLines(1);
      }

      // Footer
      if (voucherDocumentConfig?.footer != null &&
          voucherDocumentConfig!.footer!.isNotEmpty) {
        bytes += generator.text(
          voucherDocumentConfig.footer!,
          styles: PosStyles(
            align: PosAlign.center,
            height: textSizeSmall,
            fontType: fontType,
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
          message: 'Supplier Voucher printed successfully',
        );
      }
    } catch (e) {
      debugPrint('Error printing supplier voucher: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error printing: $e',
        );
      }
    }
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
