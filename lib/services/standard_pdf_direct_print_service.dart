import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:printing/printing.dart';

/// Sends an A4/A5 PDF to the operating-system printer selected in EPOS.
///
/// Raw Bluetooth/USB receipt devices are not system PDF printers. On platforms
/// where printer enumeration or direct PDF printing is unavailable, callers
/// receive `false` and can retain the existing save/open/share fallback.
class StandardPdfDirectPrintService {
  const StandardPdfDirectPrintService._();

  static PdfPageFormat pageFormatFor(String paperSize) =>
      paperSize.toUpperCase() == 'A5' ? PdfPageFormat.a5 : PdfPageFormat.a4;

  static Printer? matchPrinter(
    BluetoothPrinter selectedPrinter,
    Iterable<Printer> systemPrinters,
  ) {
    final available = systemPrinters.where((printer) => printer.isAvailable);
    final selectedUrl = selectedPrinter.address?.trim();
    if (selectedUrl != null && selectedUrl.isNotEmpty) {
      for (final printer in available) {
        if (printer.url == selectedUrl) return printer;
      }
    }

    final selectedName = _normalize(selectedPrinter.deviceName);
    if (selectedName.isEmpty) return null;
    for (final printer in available) {
      if (_normalize(printer.name) == selectedName) return printer;
    }
    return null;
  }

  static Future<bool> printDocument({
    required pw.Document document,
    required BluetoothPrinter selectedPrinter,
    required String paperSize,
    required String jobName,
    bool? usePrinterSettings,
  }) async {
    return printBytes(
      pdfBytes: await document.save(),
      selectedPrinter: selectedPrinter,
      paperSize: paperSize,
      jobName: jobName,
      usePrinterSettings: usePrinterSettings,
    );
  }

  static Future<bool> printBytes({
    required Uint8List pdfBytes,
    required BluetoothPrinter selectedPrinter,
    required String paperSize,
    required String jobName,

    /// Use the installed printer driver's saved media configuration instead
    /// of the requested PDF paper size. This is useful for barcode/label
    /// printers, but standard A4/A5 documents should keep the default false.
    /// When omitted, the value selected in Printer Settings is used.
    bool? usePrinterSettings,
  }) async {
    if (selectedPrinter.isDevelopment) return false;

    try {
      final resolvedUsePrinterSettings = usePrinterSettings ??
          await CommonPrintSettings.loadUsePrinterSettings();
      final info = await Printing.info();
      if (!info.canPrint || !info.canListPrinters) {
        debugPrint(
          '[StandardPdfDirectPrintService] Direct printer selection is not '
          'supported on this platform; using PDF fallback.',
        );
        return false;
      }

      final printer = matchPrinter(
        selectedPrinter,
        await Printing.listPrinters(),
      );
      if (printer == null) {
        debugPrint(
          '[StandardPdfDirectPrintService] Selected printer '
          '"${selectedPrinter.deviceName}" is not an available system printer; '
          'using PDF fallback.',
        );
        return false;
      }

      final printed = await Printing.directPrintPdf(
        printer: printer,
        name: jobName,
        format: pageFormatFor(paperSize),
        dynamicLayout: false,
        // Standard PDF jobs use the requested A4/A5 format by default. Label
        // callers can opt into the installed queue's settings when their
        // custom media is defined by the printer driver.
        usePrinterSettings: resolvedUsePrinterSettings,
        onLayout: (_) async => pdfBytes,
      );
      debugPrint(
        '[StandardPdfDirectPrintService] Print job "$jobName" sent to '
        '"${printer.name}": $printed',
      );
      return printed;
    } catch (error, stackTrace) {
      debugPrint(
        '[StandardPdfDirectPrintService] Direct printing failed: $error',
      );
      debugPrint('$stackTrace');
      return false;
    }
  }

  static String _normalize(String? value) =>
      (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
