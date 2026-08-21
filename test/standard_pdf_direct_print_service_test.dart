import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart'
    show PrinterType;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/services/standard_pdf_direct_print_service.dart';
import 'package:printing/printing.dart' as system_printing;

void main() {
  group('StandardPdfDirectPrintService.matchPrinter', () {
    const printers = [
      system_printing.Printer(
          url: 'windows-printer://office', name: 'Office LaserJet'),
      system_printing.Printer(
          url: 'windows-printer://backup', name: 'Backup Printer'),
    ];

    test('prefers the persisted system printer URL', () {
      final selected = BluetoothPrinter(
        deviceName: 'Renamed printer',
        address: 'windows-printer://office',
        typePrinter: PrinterType.usb,
      );

      expect(
        StandardPdfDirectPrintService.matchPrinter(selected, printers)?.url,
        'windows-printer://office',
      );
    });

    test('falls back to a normalized printer name for legacy settings', () {
      final selected = BluetoothPrinter(
        deviceName: '  OFFICE   laserjet ',
        typePrinter: PrinterType.usb,
      );

      expect(
        StandardPdfDirectPrintService.matchPrinter(selected, printers)?.url,
        'windows-printer://office',
      );
    });

    test('does not use an unavailable printer', () {
      final selected = BluetoothPrinter(
        deviceName: 'Offline',
        address: 'windows-printer://offline',
        typePrinter: PrinterType.usb,
      );
      const offline = system_printing.Printer(
        url: 'windows-printer://offline',
        name: 'Offline',
        isAvailable: false,
      );

      expect(
        StandardPdfDirectPrintService.matchPrinter(selected, [offline]),
        isNull,
      );
    });
  });
}
