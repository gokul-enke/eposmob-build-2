import 'dart:io';

import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late Directory outputDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    outputDirectory =
        await Directory.systemTemp.createTemp('epos_development_printer_');
  });

  tearDown(() async {
    if (await outputDirectory.exists()) {
      await outputDirectory.delete(recursive: true);
    }
  });

  group('BluetoothPrinter development sentinel', () {
    test('has a stable local-only identity', () {
      final printer = BluetoothPrinter.development();

      expect(
        printer.deviceName,
        BluetoothPrinter.developmentPrinterName,
      );
      expect(
        printer.address,
        BluetoothPrinter.developmentPrinterAddress,
      );
      expect(printer.typePrinter, PrinterType.usb);
      expect(printer.isDevelopment, isTrue);
      expect(printer.isConnected, isFalse);

      expect(
        BluetoothPrinter(
          deviceName: 'Production printer',
          address: 'AA:BB:CC:DD:EE:FF',
        ).isDevelopment,
        isFalse,
      );
    });

    test('bypasses physical connect, send, and disconnect calls', () async {
      final printer = BluetoothPrinter.development();
      final printerUtils = ThermalPrinterUtils();

      await printerUtils.connectToPrinter(printer);
      await printerUtils.sendPrintJob(printer, <int>[27, 64, 29, 86, 0]);
      await printerUtils.disconnectPrinter(printer);
    });
  });

  group('Developer Mode preferences', () {
    test('is off by default and ignores a saved target while off', () async {
      await DevelopmentPrinterService.selectForTarget(
        'default_printer',
        selected: true,
        preferences: preferences,
      );

      expect(
        await DevelopmentPrinterService.isEnabled(preferences: preferences),
        isFalse,
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          'default_printer',
          preferences: preferences,
        ),
        isFalse,
      );
    });

    test('persists the enabled setting', () async {
      await DevelopmentPrinterService.setEnabled(
        true,
        preferences: preferences,
      );
      await preferences.reload();

      expect(
        preferences.getBool(DevelopmentPrinterService.developerModeKey),
        isTrue,
      );
      expect(
        await DevelopmentPrinterService.isEnabled(preferences: preferences),
        isTrue,
      );
    });

    test('keeps targets independent and applies fallback only when eligible',
        () async {
      const defaultTarget = 'default_printer';
      const invoiceTarget = 'invoice_printer';
      const quotationTarget = 'quotation_printer';

      await DevelopmentPrinterService.setEnabled(
        true,
        preferences: preferences,
      );
      await DevelopmentPrinterService.selectForTarget(
        defaultTarget,
        selected: true,
        preferences: preferences,
      );

      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          invoiceTarget,
          fallbackPrinterPreferenceKey: defaultTarget,
          preferences: preferences,
        ),
        isTrue,
        reason: 'an unconfigured target should inherit the default target',
      );

      await DevelopmentPrinterService.selectForTarget(
        invoiceTarget,
        selected: false,
        preferences: preferences,
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          invoiceTarget,
          fallbackPrinterPreferenceKey: defaultTarget,
          preferences: preferences,
        ),
        isFalse,
        reason: 'an explicit target choice should win over the fallback',
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          quotationTarget,
          fallbackPrinterPreferenceKey: defaultTarget,
          preferences: preferences,
        ),
        isTrue,
        reason: 'changing one target must not affect another target',
      );

      await preferences.setString(
        quotationTarget,
        '{"deviceName":"Production printer"}',
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          quotationTarget,
          fallbackPrinterPreferenceKey: defaultTarget,
          preferences: preferences,
        ),
        isFalse,
        reason: 'a physical target preference blocks inherited development',
      );

      await DevelopmentPrinterService.selectForTarget(
        quotationTarget,
        selected: true,
        preferences: preferences,
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          quotationTarget,
          fallbackPrinterPreferenceKey: defaultTarget,
          preferences: preferences,
        ),
        isTrue,
        reason: 'an explicit development selection wins for that target',
      );
    });

    test('development selections preserve physical printer preferences',
        () async {
      const target = 'default_printer';
      const physicalPrinterJson =
          '{"deviceName":"Front Desk","address":"10.0.0.7"}';
      await preferences.setString(target, physicalPrinterJson);

      await DevelopmentPrinterService.setEnabled(
        true,
        preferences: preferences,
      );
      await DevelopmentPrinterService.selectForTarget(
        target,
        selected: true,
        preferences: preferences,
      );

      expect(preferences.getString(target), physicalPrinterJson);
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          target,
          preferences: preferences,
        ),
        isTrue,
      );

      await DevelopmentPrinterService.selectForTarget(
        target,
        selected: false,
        preferences: preferences,
      );
      expect(preferences.getString(target), physicalPrinterJson);
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          target,
          preferences: preferences,
        ),
        isFalse,
      );
    });

    test('disabling clears overrides and restores physical-only behavior',
        () async {
      const physicalTarget = 'default_printer';
      const developmentOnlyTarget = 'quotation_printer';
      const physicalPrinterJson =
          '{"deviceName":"Kitchen","address":"192.168.1.20"}';
      await preferences.setString(physicalTarget, physicalPrinterJson);
      await DevelopmentPrinterService.setEnabled(
        true,
        preferences: preferences,
      );
      await DevelopmentPrinterService.selectForTarget(
        physicalTarget,
        selected: true,
        preferences: preferences,
      );
      await DevelopmentPrinterService.selectForTarget(
        developmentOnlyTarget,
        selected: true,
        preferences: preferences,
      );

      await DevelopmentPrinterService.setEnabled(
        false,
        preferences: preferences,
      );

      expect(
        await DevelopmentPrinterService.isEnabled(preferences: preferences),
        isFalse,
      );
      expect(preferences.getString(physicalTarget), physicalPrinterJson);
      expect(
        preferences.getKeys().where(
              (key) => key.startsWith('development_printer_selected_for_'),
            ),
        isEmpty,
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          developmentOnlyTarget,
          fallbackPrinterPreferenceKey: physicalTarget,
          preferences: preferences,
        ),
        isFalse,
      );

      await DevelopmentPrinterService.setEnabled(
        true,
        preferences: preferences,
      );
      expect(
        await DevelopmentPrinterService.shouldUseForTarget(
          developmentOnlyTarget,
          fallbackPrinterPreferenceKey: physicalTarget,
          preferences: preferences,
        ),
        isFalse,
        reason: 'disabling must not leave dormant development overrides',
      );
    });
  });

  group('Development printer output', () {
    test('writes each PDF to a unique file in the injected directory',
        () async {
      final first = await DevelopmentPrinterService.savePdf(
        bytes: <int>[1, 2, 3, 4],
        orderNumber: 'Order / 42',
        layoutId: 'Tax Invoice',
        outputDirectory: outputDirectory,
      );
      final second = await DevelopmentPrinterService.savePdf(
        bytes: <int>[5, 6, 7],
        orderNumber: 'Order / 42',
        layoutId: 'Tax Invoice',
        outputDirectory: outputDirectory,
      );

      expect(first.parent.path, outputDirectory.path);
      expect(second.parent.path, outputDirectory.path);
      expect(first.path, isNot(second.path));
      expect(first.path, endsWith('.pdf'));
      expect(await first.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(await second.readAsBytes(), <int>[5, 6, 7]);
      expect(
        await outputDirectory
            .list()
            .where((entry) => entry.path.endsWith('.pdf'))
            .length,
        2,
      );
    });

    test('writes a PNG with the combined thermal receipt dimensions', () async {
      final firstPart = img.Image(width: 4, height: 3, numChannels: 4);
      img.fill(firstPart, color: img.ColorRgb8(255, 0, 0));
      final secondPart = img.Image(width: 6, height: 2, numChannels: 4);
      img.fill(secondPart, color: img.ColorRgb8(0, 0, 255));

      final file = await DevelopmentPrinterService.saveThermalReceipt(
        firstPart: firstPart,
        secondPart: secondPart,
        paperSize: '80 mm',
        orderNumber: 'Order 99',
        layoutId: 'classic layout',
        outputDirectory: outputDirectory,
      );
      final decoded = img.decodePng(await file.readAsBytes());

      expect(file.parent.path, outputDirectory.path);
      expect(file.path, endsWith('.png'));
      expect(decoded, isNotNull);
      expect(decoded!.width, 6);
      expect(decoded.height, 5);
    });

    test('includes the native order barcode in a thermal preview', () async {
      final firstPart = img.Image(width: 240, height: 3, numChannels: 4);
      img.fill(firstPart, color: img.ColorRgb8(255, 255, 255));
      final secondPart = img.Image(width: 240, height: 2, numChannels: 4);
      img.fill(secondPart, color: img.ColorRgb8(255, 255, 255));

      final file = await DevelopmentPrinterService.saveThermalReceipt(
        firstPart: firstPart,
        secondPart: secondPart,
        paperSize: '80mm',
        orderNumber: 'ORDER-99',
        layoutId: 'classic',
        outputDirectory: outputDirectory,
      );
      final decoded = img.decodePng(await file.readAsBytes())!;
      final barcodePixels = decoded.getRange(
        0,
        firstPart.height + secondPart.height,
        decoded.width,
        decoded.height - firstPart.height - secondPart.height,
      );
      var hasBlackBar = false;
      while (barcodePixels.moveNext()) {
        final pixel = barcodePixels.current;
        if (pixel.r == 0 && pixel.g == 0 && pixel.b == 0) {
          hasBlackBar = true;
          break;
        }
      }

      expect(decoded.height, 79);
      expect(hasBlackBar, isTrue);
    });
  });
}
