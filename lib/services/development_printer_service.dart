import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local settings and file output for the virtual development printer.
///
/// Development selections are deliberately stored separately from physical
/// printer JSON. This preserves every production printer selection while the
/// virtual printer is active and restores it immediately when Developer Mode is
/// turned off.
class DevelopmentPrinterService {
  static const String developerModeKey = 'developer_mode_enabled';
  static const String _targetOverridePrefix =
      'development_printer_selected_for_';

  static int _lastOutputId = 0;

  static BluetoothPrinter get printer => BluetoothPrinter.development();

  static Future<bool> isEnabled({
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return prefs.getBool(developerModeKey) ?? false;
  }

  static Future<void> setEnabled(
    bool enabled, {
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final saved = await prefs.setBool(developerModeKey, enabled);
    if (!saved) {
      throw StateError('Could not save Developer Mode setting');
    }

    if (!enabled) {
      final overrideKeys = prefs
          .getKeys()
          .where((key) => key.startsWith(_targetOverridePrefix))
          .toList(growable: false);
      for (final key in overrideKeys) {
        await prefs.remove(key);
      }
    }
  }

  static String _overrideKey(String printerPreferenceKey) =>
      '$_targetOverridePrefix$printerPreferenceKey';

  static Future<void> selectForTarget(
    String printerPreferenceKey, {
    required bool selected,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final saved =
        await prefs.setBool(_overrideKey(printerPreferenceKey), selected);
    if (!saved) {
      throw StateError('Could not save development printer selection');
    }
  }

  static Future<void> clearTargetSelection(
    String printerPreferenceKey, {
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(_overrideKey(printerPreferenceKey));
  }

  /// Resolves the virtual override using the same fallback behavior as printer
  /// JSON: an explicitly configured target wins; otherwise an optional default
  /// target can be inherited.
  static Future<bool> shouldUseForTarget(
    String printerPreferenceKey, {
    String? fallbackPrinterPreferenceKey,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    if (!(prefs.getBool(developerModeKey) ?? false)) return false;

    final overrideKey = _overrideKey(printerPreferenceKey);
    if (prefs.containsKey(overrideKey)) {
      return prefs.getBool(overrideKey) ?? false;
    }

    if (prefs.containsKey(printerPreferenceKey)) return false;

    if (fallbackPrinterPreferenceKey != null) {
      return prefs.getBool(_overrideKey(fallbackPrinterPreferenceKey)) ??
          false;
    }
    return false;
  }

  static Future<Directory> getOutputDirectory() async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory =
          Directory('${documents.path}/epos/developer_prints');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } catch (error) {
      debugPrint(
        '[DevelopmentPrinter] Documents folder unavailable, using temp: '
        '$error',
      );
      final temporary = await getTemporaryDirectory();
      final directory =
          Directory('${temporary.path}/epos_developer_prints');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
  }

  static Future<File> savePdf({
    required List<int> bytes,
    required String orderNumber,
    required String layoutId,
    Directory? outputDirectory,
  }) async {
    final directory = outputDirectory ?? await getOutputDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(
      '${directory.path}/'
      '${_safePart(layoutId)}_${_safePart(orderNumber)}_'
      '${_nextOutputId()}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('[DevelopmentPrinter] PDF saved to ${file.path}');
    return file;
  }

  static Future<File> saveThermalReceipt({
    required img.Image firstPart,
    required img.Image secondPart,
    required String paperSize,
    required String orderNumber,
    required String layoutId,
    Directory? outputDirectory,
  }) async {
    final width =
        firstPart.width > secondPart.width ? firstPart.width : secondPart.width;
    const barcodeHeight = 50.0;
    const barcodeVerticalPadding = 12;
    var barcodeWidth = 0.0;
    var barcodeBars = <pw.BarcodeBar>[];
    final cleanOrderNumber =
        orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
    if (width >= 120 && cleanOrderNumber.isNotEmpty) {
      try {
        barcodeWidth = (width - 40).toDouble();
        barcodeBars = pw.Barcode.code39()
            .make(
              cleanOrderNumber,
              width: barcodeWidth,
              height: barcodeHeight,
              drawText: false,
            )
            .whereType<pw.BarcodeBar>()
            .where((bar) => bar.black)
            .toList(growable: false);
      } catch (error) {
        debugPrint(
          '[DevelopmentPrinter] Could not render order barcode: $error',
        );
      }
    }
    final barcodeSectionHeight = barcodeBars.isEmpty
        ? 0
        : barcodeHeight.ceil() + (barcodeVerticalPadding * 2);
    final combined = img.Image(
      width: width,
      height: firstPart.height + secondPart.height + barcodeSectionHeight,
      numChannels: 4,
    );
    img.fill(combined, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      combined,
      firstPart,
      dstX: (width - firstPart.width) ~/ 2,
      blend: img.BlendMode.direct,
    );
    img.compositeImage(
      combined,
      secondPart,
      dstX: (width - secondPart.width) ~/ 2,
      dstY: firstPart.height,
      blend: img.BlendMode.direct,
    );
    if (barcodeBars.isNotEmpty) {
      final xOffset = (width - barcodeWidth) / 2;
      final yOffset =
          firstPart.height + secondPart.height + barcodeVerticalPadding;
      for (final bar in barcodeBars) {
        final x1 = (xOffset + bar.left).floor();
        final y1 = (yOffset + bar.top).floor();
        final x2 = (xOffset + bar.right).ceil() - 1;
        final y2 = (yOffset + bar.bottom).ceil() - 1;
        if (x2 >= x1 && y2 >= y1) {
          img.fillRect(
            combined,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            color: img.ColorRgb8(0, 0, 0),
            alphaBlend: false,
          );
        }
      }
    }

    final directory = outputDirectory ?? await getOutputDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(
      '${directory.path}/'
      '${_safePart(layoutId)}_${_safePart(orderNumber)}_'
      '${_safePart(paperSize)}_${_nextOutputId()}.png',
    );
    await file.writeAsBytes(img.encodePng(combined), flush: true);
    debugPrint('[DevelopmentPrinter] Thermal image saved to ${file.path}');
    return file;
  }

  static String _safePart(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return safe.isEmpty ? 'output' : safe;
  }

  static int _nextOutputId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastOutputId = now > _lastOutputId ? now : _lastOutputId + 1;
    return _lastOutputId;
  }
}
