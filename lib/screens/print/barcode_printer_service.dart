import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/screens/product/widgets/confirm_barcode_print_modal.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';
import 'package:pos_machine/screens/print/barcode_bidi_text.dart';
import 'package:pos_machine/screens/print/barcode_sticker_image_renderer.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:pos_machine/models/barcode_layout_settings.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BarcodePrintStatus {
  sentToPrinter,
  pdfOpened,
  pdfShared,
  pdfSaved,
  failed,
}

class BarcodePrintResult {
  final BarcodePrintStatus status;
  final String message;

  const BarcodePrintResult(this.status, this.message);

  bool get isSuccess =>
      status == BarcodePrintStatus.sentToPrinter ||
      status == BarcodePrintStatus.pdfOpened ||
      status == BarcodePrintStatus.pdfShared;
}

enum _DirectPrintStatus { notConfigured, unsupported, success, failed }

class _DirectPrintResult {
  final _DirectPrintStatus status;
  final String message;

  const _DirectPrintResult(this.status, this.message);
}

class _RenderedBarcodeSticker {
  final Uint8List pngBytes;
  final pw.Widget widget;

  const _RenderedBarcodeSticker({
    required this.pngBytes,
    required this.widget,
  });
}

/// Barcode Printer Service
/// Generates a PDF of barcode stickers and opens/shares it (same pattern as DailyCloseStandardPrinter).
class BarcodePrinterService {
  final BuildContext context;

  BarcodePrinterService(this.context);

  DocumentConfig? _resolveBarcodeConfig() {
    try {
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      // Preferred lookup by key used across the app.
      final byKey = docConfigProvider.getDocumentConfig('Barcode');
      if (byKey != null) {
        debugPrint(
            '[BarcodePrint] Using Barcode config by key: id=${byKey.id}, updatedAt=${byKey.updatedAt}, template=${byKey.template}');
        return byKey;
      }

      // Fallback lookup by config.type for resilience against key variations.
      final configs =
          docConfigProvider.documentConfigurations?.documentConfigurations;
      if (configs == null) {
        debugPrint(
            '[BarcodePrint] Document config map is null; falling back to defaults.');
        return null;
      }

      debugPrint(
          '[BarcodePrint] Barcode key not found. Available config keys: ${configs.keys.toList()}');

      for (final config in configs.values) {
        if ((config.type ?? '').toLowerCase() == 'barcode') {
          debugPrint(
              '[BarcodePrint] Using Barcode config by type fallback: id=${config.id}, updatedAt=${config.updatedAt}, template=${config.template}');
          return config;
        }
      }
    } catch (e) {
      debugPrint('[BarcodePrint] Error resolving barcode config: $e');
      // Keep silent and use defaults when provider is not available.
    }
    debugPrint('[BarcodePrint] No Barcode config found; using defaults.');
    return null;
  }

  Future<Directory> _getEposDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${documentsDir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
      }
      return eposDir;
    } catch (e) {
      debugPrint('Could not access Documents/epos directory, using temp: $e');
      return await getTemporaryDirectory();
    }
  }

  Future<BluetoothPrinter?> _loadSelectedBarcodePrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('barcode_printer');
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> printerData =
          json.decode(raw) as Map<String, dynamic>;

      return BluetoothPrinter(
        deviceName: printerData['deviceName'] as String?,
        address: printerData['address'] as String?,
        vendorId: printerData['vendorId'] as String?,
        productId: printerData['productId'] as String?,
        typePrinter: PrinterType.values.firstWhere(
          (e) => e.toString() == printerData['typePrinter'],
          orElse: () => PrinterType.bluetooth,
        ),
      );
    } catch (e) {
      debugPrint('[BarcodePrint] Failed to parse saved barcode printer: $e');
      return null;
    }
  }

  String _normalizeProductNameMode(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    switch (normalized) {
      case 'ar':
      case 'en':
      case 'en/ar':
      case 'ar/en':
        return normalized;
      default:
        return 'en/ar';
    }
  }

  String? _barcodeDensityError(
    String value,
    BarcodeLayoutSettings settings,
    String stickerSize,
  ) {
    final dimensions = settings.copyWith(stickerSize: stickerSize);
    final pixelWidth = dimensions.stickerWidthMm *
        settings.rasterDpi /
        25.4 *
        settings.barcodeWidthPercent /
        100;
    final elements = pw.Barcode.code128().make(
      value,
      width: pixelWidth,
      height: 60,
      drawText: false,
    );
    final widths = elements
        .whereType<pw.BarcodeBar>()
        .map((bar) => bar.width)
        .where((width) => width > 0);
    if (widths.isEmpty) return 'Barcode produced no printable bars';
    final narrowest = widths.reduce((a, b) => a < b ? a : b);
    if (narrowest < 1.5) {
      return 'Barcode width is too small for this value at '
          '${settings.rasterDpi} DPI. Increase Barcode Width or sticker size.';
    }
    return null;
  }

  String _extractTranslatedName(dynamic names, String languageCode) {
    if (names == null) return '';
    final targetCode = languageCode.toLowerCase();

    if (names is Map) {
      final direct = names[targetCode] ?? names[languageCode];
      if (direct is String) {
        return direct.trim();
      }
      if (direct is Map) {
        final fromMap = direct['name'] ?? direct['value'];
        if (fromMap != null) {
          return fromMap.toString().trim();
        }
      }

      for (final value in names.values) {
        if (value is! Map) continue;
        final code = value['code']?.toString().toLowerCase() ??
            value['language_code']?.toString().toLowerCase();
        if (code != targetCode) continue;

        final translated = value['name'] ?? value['value'];
        if (translated != null) {
          return translated.toString().trim();
        }
      }
    }

    return '';
  }

  String _resolveProductName(GetProduct product, String productNameMode) {
    final englishName = _extractTranslatedName(product.names, 'en');
    final arabicName = _extractTranslatedName(product.names, 'ar');
    final fallbackName = (product.productName ?? '').trim();

    switch (_normalizeProductNameMode(productNameMode)) {
      case 'ar':
        return arabicName.isNotEmpty
            ? arabicName
            : englishName.isNotEmpty
                ? englishName
                : fallbackName;
      case 'en/ar':
        final resolvedEnglish =
            englishName.isNotEmpty ? englishName : fallbackName;
        return BarcodeBidiText.englishThenArabic(
          resolvedEnglish,
          arabicName,
        );
      case 'ar/en':
        final resolvedEnglish =
            englishName.isNotEmpty ? englishName : fallbackName;
        return BarcodeBidiText.arabicThenEnglish(
          arabicName,
          resolvedEnglish,
        );
      case 'en':
      default:
        return englishName.isNotEmpty
            ? englishName
            : fallbackName.isNotEmpty
                ? fallbackName
                : arabicName;
    }
  }

  Future<_DirectPrintResult> _tryDirectPrintToSelectedPrinter({
    required List<BarcodePrintItem> printItems,
    required String stickerSize,
    required int stickersPerRow,
    required BarcodeLayoutSettings layoutSettings,
    required String storeName,
    required String currency,
    required bool showStoreName,
    required bool showProductName,
    required String productNameMode,
    required bool showPrice,
    required bool showBarcodeNumber,
    required bool showMfgDate,
    required bool showExpiryDate,
  }) async {
    final selectedPrinter = await _loadSelectedBarcodePrinter();
    if (selectedPrinter == null) {
      return const _DirectPrintResult(
        _DirectPrintStatus.notConfigured,
        'No barcode printer configured',
      );
    }

    final dimensions = layoutSettings.copyWith(stickerSize: stickerSize);
    final totalLabels = printItems.fold<int>(
      0,
      (total, item) => total + item.quantity.clamp(0, 999).toInt(),
    );
    if (stickersPerRow != 1 ||
        dimensions.stickerWidthMm > 80 ||
        totalLabels > 200) {
      return const _DirectPrintResult(
        _DirectPrintStatus.unsupported,
        'This layout requires the PDF print path',
      );
    }

    final printerUtils = ThermalPrinterUtils();
    try {
      final profile = await CapabilityProfile.load();
      final paperSize =
          dimensions.stickerWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
      final maxRasterWidth = paperSize == PaperSize.mm58 ? 384 : 576;
      final generator = Generator(paperSize, profile);
      final bytes = <int>[];

      for (final item in printItems) {
        if (item.quantity < 1) continue;
        final product = item.product;
        final barcodeValue = (product.barcode ?? '').trim();
        final rawPriceText =
            (product.price?.price ?? product.mrp ?? 'N/A').toString().trim();
        final parsedPrice = double.tryParse(rawPriceText);
        final priceToShow =
            parsedPrice != null ? parsedPrice.toStringAsFixed(2) : rawPriceText;
        var dateLine = '';
        if (showMfgDate && item.mfgDate != null) {
          dateLine += 'P:${DateFormat('dd/MM/yyyy').format(item.mfgDate!)}';
        }
        if (showExpiryDate && item.expDate != null) {
          if (dateLine.isNotEmpty) dateLine += ' ';
          dateLine += 'E:${DateFormat('dd/MM/yyyy').format(item.expDate!)}';
        }

        final pngBytes = await BarcodeStickerImageRenderer.render(
          widthMm: dimensions.stickerWidthMm,
          heightMm: dimensions.stickerHeightMm,
          storeName: showStoreName ? storeName : '',
          barcodeValue: barcodeValue,
          showBarcodeNumber: showBarcodeNumber,
          productName: showProductName
              ? _resolveProductName(product, productNameMode)
              : '',
          priceText: showPrice ? priceToShow : '',
          currency: currency,
          dateLine: dateLine,
          storeNameFontSize: layoutSettings.storeNameFontSize,
          productNameFontSize: layoutSettings.productNameFontSize,
          priceFontSize: layoutSettings.priceFontSize,
          dateFontSize: layoutSettings.dateFontSize,
          barcodeNumberFontSize: layoutSettings.barcodeNumberFontSize,
          barcodeHeight: layoutSettings.barcodeHeight,
          barcodeWidthPercent: layoutSettings.barcodeWidthPercent,
          elementSpacing: layoutSettings.elementSpacing,
          pixelsPerMm: layoutSettings.rasterDpi / 25.4,
        );
        final decoded = pngBytes == null ? null : img.decodeImage(pngBytes);
        if (decoded == null) {
          return _DirectPrintResult(
            _DirectPrintStatus.failed,
            'Could not render ${product.productName ?? 'a barcode label'}',
          );
        }
        final raster = decoded.width > maxRasterWidth
            ? img.copyResize(decoded, width: maxRasterWidth)
            : decoded;
        final labelBytes = generator.image(raster, align: PosAlign.center);
        for (var i = 0; i < item.quantity; i++) {
          bytes.addAll(labelBytes);
          bytes.addAll(generator.feed(1));
        }
      }

      if (bytes.isEmpty) {
        return const _DirectPrintResult(
          _DirectPrintStatus.failed,
          'Nothing to print',
        );
      }
      bytes.addAll(generator.cut());

      // Build the complete job before connecting so rendering failures cannot
      // create a partially printed batch.
      await printerUtils.connectToPrinter(selectedPrinter);
      await printerUtils.sendPrintJob(selectedPrinter, bytes);
      return _DirectPrintResult(
        _DirectPrintStatus.success,
        'Sent to printer: ${selectedPrinter.deviceName ?? 'Barcode printer'}',
      );
    } catch (error, stackTrace) {
      debugPrint('[BarcodePrint] Direct print failed: $error');
      debugPrint('[BarcodePrint] Direct print stack: $stackTrace');
      return _DirectPrintResult(
        _DirectPrintStatus.failed,
        'Direct printing failed: $error',
      );
    } finally {
      await printerUtils.disconnectPrinter(selectedPrinter);
    }
  }

  Uint8List _buildRotatedBarcodePage({
    required List<_RenderedBarcodeSticker> stickers,
    required double pageWidthMm,
    required double pageHeightMm,
    required double stickerWidthMm,
    required double stickerHeightMm,
    required double pageMarginMm,
    required double gapMm,
    required int dpi,
    required int rotationDegrees,
    required bool invertPrintColors,
  }) {
    int pixels(double mm) => (mm * dpi / 25.4).round().clamp(1, 100000);

    final page = img.Image(
      width: pixels(pageWidthMm),
      height: pixels(pageHeightMm),
      numChannels: 4,
    );
    img.fill(page, color: img.ColorRgb8(255, 255, 255));

    final stickerWidthPx = pixels(stickerWidthMm);
    final stickerHeightPx = pixels(stickerHeightMm);
    final marginPx = (pageMarginMm * dpi / 25.4).round();
    final gapPx = (gapMm * dpi / 25.4).round();

    for (var index = 0; index < stickers.length; index++) {
      final decoded = img.decodeImage(stickers[index].pngBytes);
      if (decoded == null) continue;
      final normalized =
          decoded.width == stickerWidthPx && decoded.height == stickerHeightPx
              ? decoded
              : img.copyResize(
                  decoded,
                  width: stickerWidthPx,
                  height: stickerHeightPx,
                  interpolation: img.Interpolation.nearest,
                );
      img.compositeImage(
        page,
        normalized,
        dstX: marginPx + index * (stickerWidthPx + gapPx),
        dstY: marginPx,
      );
    }

    final colorAdjusted = invertPrintColors ? img.invert(page) : page;
    final rotated = rotationDegrees == 0
        ? colorAdjusted
        : img.copyRotate(
            colorAdjusted,
            angle: rotationDegrees,
            interpolation: img.Interpolation.nearest,
          );
    return Uint8List.fromList(img.encodePng(rotated));
  }

  /// Generate a barcode sticker PDF and open/share it.
  Future<BarcodePrintResult> printBarcodes({
    required List<BarcodePrintItem> printItems,
    String stickerSize = '50x25mm',
    int stickersPerRow = 1,
    int? printRotationDegrees,
    bool invertPrintColors = false,
  }) async {
    if (printItems.isEmpty) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'No stocks selected to print.',
        );
      }
      return const BarcodePrintResult(
        BarcodePrintStatus.failed,
        'No stocks selected to print.',
      );
    }

    final totalLabels = printItems.fold<int>(
      0,
      (total, item) => total + item.quantity.clamp(0, 999).toInt(),
    );
    if (totalLabels < 1 || totalLabels > 2000) {
      final message = totalLabels < 1
          ? 'Nothing to print. Enter a quantity for at least one item.'
          : 'This job contains $totalLabels labels. Reduce it to 2000 or fewer.';
      if (context.mounted) {
        showScaffoldError(context: context, message: message);
      }
      return BarcodePrintResult(BarcodePrintStatus.failed, message);
    }

    for (final item in printItems.where((item) => item.quantity > 0)) {
      final value = (item.product.barcode ?? '').trim();
      try {
        if (value.isEmpty) throw const FormatException('Barcode is empty');
        pw.Barcode.code128().make(
          value,
          width: 300,
          height: 100,
          drawText: false,
        );
      } catch (error) {
        final message =
            'Invalid barcode for ${item.product.productName ?? 'a product'}: $error';
        if (context.mounted) {
          showScaffoldError(context: context, message: message);
        }
        return BarcodePrintResult(BarcodePrintStatus.failed, message);
      }
    }

    try {
      debugPrint('========== BARCODE PRINT DEBUG START ==========');
      debugPrint(
          '[BarcodePrint] Request -> items=${printItems.length}, stickerSize=$stickerSize, stickersPerRow=$stickersPerRow, rotation=$printRotationDegrees');

      if (context.mounted) {
        showLoadingOverlay(
          context,
          message: 'Printing barcodes... (PDF fallback enabled)',
        );
      }

      final barcodeConfig = _resolveBarcodeConfig();
      final displayConfig = barcodeConfig?.displayConfiguration?.options;
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'SAR';

      bool readVisible(String key, {bool fallback = true}) {
        return displayConfig?[key]?.visible ?? fallback;
      }

      String readValue(String key) {
        final raw = displayConfig?[key]?.value;
        if (raw is String && raw.trim().isNotEmpty) {
          return raw.trim();
        }
        return '';
      }

      final showStoreName = readVisible('showStoreName', fallback: true);
      final showProductName = readVisible('showProductName', fallback: true);
      final productNameMode = showProductName
          ? _normalizeProductNameMode(readValue('showProductName'))
          : 'en';
      final showPrice = readVisible('showPrice', fallback: true);
      final showBarcodeNumber =
          readVisible('showBarcodeNumber', fallback: true);
      final showMfgDate = readVisible('showMfgDate', fallback: true);
      final showExpiryDate = readVisible('showExpiryDate', fallback: true);

      String storeName = readValue('showStoreName');
      if (storeName.isEmpty) {
        final header = barcodeConfig?.header?.trim();
        if (header != null && header.isNotEmpty) {
          storeName = header;
        }
      }
      if (storeName.isEmpty) {
        final sessionStoreName = Provider.of<StoreSessionProvider>(
          context,
          listen: false,
        ).activeStore?.storeName?.trim();
        if (sessionStoreName != null && sessionStoreName.isNotEmpty) {
          storeName = sessionStoreName;
        }
      }

      debugPrint(
          '[BarcodePrint] Config -> id=${barcodeConfig?.id}, type=${barcodeConfig?.type}, template=${barcodeConfig?.template}, updatedAt=${barcodeConfig?.updatedAt}');
      debugPrint(
          '[BarcodePrint] Display keys -> ${displayConfig?.keys.toList() ?? []}');
      debugPrint(
          '[BarcodePrint] Flags -> showStoreName=$showStoreName, showProductName=$showProductName, productNameMode=$productNameMode, showPrice=$showPrice, showBarcodeNumber=$showBarcodeNumber, showMfgDate=$showMfgDate, showExpiryDate=$showExpiryDate');
      debugPrint(
          "[BarcodePrint] Resolved values -> storeName='${storeName.isEmpty ? '(empty)' : storeName}', currency='$currency'");

      // Load user-configured barcode layout settings
      final layoutSettings = await loadBarcodeLayoutSettings();
      final effectiveRotation = const [90, 180, 270].contains(
        printRotationDegrees,
      )
          ? printRotationDegrees
          : null;

      for (final item in printItems.where((item) => item.quantity > 0)) {
        final barcodeValue = item.product.barcode!.trim();
        final densityError =
            _barcodeDensityError(barcodeValue, layoutSettings, stickerSize);
        if (densityError != null) {
          hideLoadingOverlay();
          final message =
              '${item.product.productName ?? 'Product'}: $densityError';
          if (context.mounted) {
            showScaffoldError(context: context, message: message);
          }
          return BarcodePrintResult(BarcodePrintStatus.failed, message);
        }
      }

      if (!Platform.isWindows &&
          effectiveRotation == null &&
          !invertPrintColors) {
        final directResult = await _tryDirectPrintToSelectedPrinter(
          printItems: printItems,
          stickerSize: stickerSize,
          stickersPerRow: stickersPerRow,
          layoutSettings: layoutSettings,
          storeName: storeName,
          currency: currency,
          showStoreName: showStoreName,
          showProductName: showProductName,
          productNameMode: productNameMode,
          showPrice: showPrice,
          showBarcodeNumber: showBarcodeNumber,
          showMfgDate: showMfgDate,
          showExpiryDate: showExpiryDate,
        );
        if (directResult.status == _DirectPrintStatus.success) {
          hideLoadingOverlay();
          if (context.mounted) {
            showScaffold(context: context, message: directResult.message);
          }
          return BarcodePrintResult(
            BarcodePrintStatus.sentToPrinter,
            directResult.message,
          );
        }
        if (directResult.status == _DirectPrintStatus.failed) {
          hideLoadingOverlay();
          if (context.mounted) {
            showScaffoldError(context: context, message: directResult.message);
          }
          return BarcodePrintResult(
            BarcodePrintStatus.failed,
            directResult.message,
          );
        }
      }

      // Use stickerSize from parameter (per-print override) but use layout
      // settings for font sizes, spacing, barcode height, margin, gap etc.
      // Sticker dimensions (in mm → points, 1mm ≈ 2.835pt)
      double stickerW;
      double stickerH;
      if (stickerSize == '30x20mm') {
        stickerW = 30 * PdfPageFormat.mm;
        stickerH = 20 * PdfPageFormat.mm;
      } else if (stickerSize == '40x20mm') {
        stickerW = 40 * PdfPageFormat.mm;
        stickerH = 20 * PdfPageFormat.mm;
      } else if (stickerSize == '40x25mm') {
        stickerW = 40 * PdfPageFormat.mm;
        stickerH = 25 * PdfPageFormat.mm;
      } else if (stickerSize == '38x25mm') {
        stickerW = 38 * PdfPageFormat.mm;
        stickerH = 25 * PdfPageFormat.mm;
      } else if (stickerSize == '55x35mm') {
        stickerW = 55 * PdfPageFormat.mm;
        stickerH = 35 * PdfPageFormat.mm;
      } else if (stickerSize == '60x40mm') {
        stickerW = 60 * PdfPageFormat.mm;
        stickerH = 40 * PdfPageFormat.mm;
      } else if (stickerSize == '70x40mm') {
        stickerW = 70 * PdfPageFormat.mm;
        stickerH = 40 * PdfPageFormat.mm;
      } else if (stickerSize == '100x50mm') {
        stickerW = 100 * PdfPageFormat.mm;
        stickerH = 50 * PdfPageFormat.mm;
      } else if (stickerSize == '91x24mm') {
        stickerW = 91 * PdfPageFormat.mm;
        stickerH = 24 * PdfPageFormat.mm;
      } else {
        // Default 50x25
        stickerW = 50 * PdfPageFormat.mm;
        stickerH = 25 * PdfPageFormat.mm;
      }

      final pdf = pw.Document();

      // Callers already clamp, but guard here too: 0/negative would divide by
      // zero below, and an absurd count would size a meter-wide page.
      final int safeStickersPerRow = stickersPerRow.clamp(1, 10);
      final double pageMargin = layoutSettings.pageMargin * PdfPageFormat.mm;
      final double gap = layoutSettings.stickerGap * PdfPageFormat.mm;
      final double rowWidth =
          (safeStickersPerRow * stickerW) + ((safeStickersPerRow - 1) * gap);
      final double pageWidth = rowWidth + (pageMargin * 2);
      final double pageHeight = stickerH + (pageMargin * 2);
      final pageFormat = PdfPageFormat(pageWidth, pageHeight);
      final swapsPageDimensions =
          effectiveRotation == 90 || effectiveRotation == 270;
      final printPageFormat = swapsPageDimensions
          ? PdfPageFormat(pageHeight, pageWidth)
          : pageFormat;

      debugPrint(
          '[BarcodePrint] Sticker(mm) -> width=${(stickerW / PdfPageFormat.mm).toStringAsFixed(2)}, height=${(stickerH / PdfPageFormat.mm).toStringAsFixed(2)}');
      debugPrint(
          '[BarcodePrint] Page(mm) -> width=${(pageWidth / PdfPageFormat.mm).toStringAsFixed(2)}, height=${(pageHeight / PdfPageFormat.mm).toStringAsFixed(2)}, rowWidth=${(rowWidth / PdfPageFormat.mm).toStringAsFixed(2)}, margin=${(pageMargin / PdfPageFormat.mm).toStringAsFixed(2)}, gap=${(gap / PdfPageFormat.mm).toStringAsFixed(2)}');

      // Build flat list of sticker widgets respecting quantity. Each unique
      // item is rasterized once via Flutter's text engine (exact line-height
      // control the pdf package lacks), then reused for all its copies.
      final List<_RenderedBarcodeSticker> stickers = [];
      for (int idx = 0; idx < printItems.length; idx++) {
        final item = printItems[idx];
        final product = item.product;
        final barcodeValue = product.barcode?.trim() ?? '';
        final resolvedProductName =
            _resolveProductName(product, productNameMode);
        debugPrint(
            "[BarcodePrint] Item[$idx] -> name='${resolvedProductName.isEmpty ? (product.productName ?? '(null)') : resolvedProductName}', qty=${item.quantity}, barcode='${barcodeValue.isEmpty ? '(empty)' : barcodeValue}', retail='${product.price?.price ?? '(null)'}', mrp='${product.mrp ?? '(null)'}', mfg=${item.mfgDate}, exp=${item.expDate}");

        if (barcodeValue.isEmpty) {
          debugPrint(
              "[BarcodePrint][WARN] Item[$idx] has no barcode; barcode image and number cannot be rendered.");
        }
        if (item.quantity < 1) {
          debugPrint(
              '[BarcodePrint][WARN] Item[$idx] quantity is ${item.quantity}; it will not produce stickers.');
          continue;
        }

        final rawPriceText =
            (product.price?.price ?? product.mrp ?? 'N/A').toString().trim();
        final parsedPrice = double.tryParse(rawPriceText);
        final priceToShow =
            parsedPrice != null ? parsedPrice.toStringAsFixed(2) : rawPriceText;

        String dateLine = '';
        if (showMfgDate && item.mfgDate != null) {
          dateLine += "P:${DateFormat('dd/MM/yyyy').format(item.mfgDate!)}";
        }
        if (showExpiryDate && item.expDate != null) {
          if (dateLine.isNotEmpty) dateLine += ' ';
          dateLine += "E:${DateFormat('dd/MM/yyyy').format(item.expDate!)}";
        }

        final pngBytes = await BarcodeStickerImageRenderer.render(
          widthMm: stickerW / PdfPageFormat.mm,
          heightMm: stickerH / PdfPageFormat.mm,
          storeName: showStoreName ? storeName : '',
          barcodeValue: barcodeValue,
          showBarcodeNumber: showBarcodeNumber,
          productName: showProductName ? resolvedProductName : '',
          priceText: showPrice ? priceToShow : '',
          currency: currency,
          dateLine: dateLine,
          storeNameFontSize: layoutSettings.storeNameFontSize,
          productNameFontSize: layoutSettings.productNameFontSize,
          priceFontSize: layoutSettings.priceFontSize,
          dateFontSize: layoutSettings.dateFontSize,
          barcodeNumberFontSize: layoutSettings.barcodeNumberFontSize,
          barcodeHeight: layoutSettings.barcodeHeight,
          barcodeWidthPercent: layoutSettings.barcodeWidthPercent,
          elementSpacing: layoutSettings.elementSpacing,
          pixelsPerMm: layoutSettings.rasterDpi / 25.4,
        );

        if (pngBytes == null) {
          debugPrint(
              '[BarcodePrint][WARN] Item[$idx] produced no sticker image.');
          continue;
        }

        final stickerImage = pw.MemoryImage(pngBytes);
        final stickerWidget = pw.Image(
          stickerImage,
          width: stickerW,
          height: stickerH,
        );
        for (int i = 0; i < item.quantity; i++) {
          stickers.add(
            _RenderedBarcodeSticker(
              pngBytes: pngBytes,
              widget: stickerWidget,
            ),
          );
        }
      }

      if (stickers.isEmpty) {
        hideLoadingOverlay();
        debugPrint(
            '[BarcodePrint] No printable stickers (all quantities zero or nothing to render). Aborting before PDF save.');
        debugPrint('========== BARCODE PRINT DEBUG END ==========');
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message:
                'Nothing to print. Check item quantities and barcode display settings.',
          );
        }
        return const BarcodePrintResult(
          BarcodePrintStatus.failed,
          'Nothing to print.',
        );
      }

      final totalPages = (stickers.length / safeStickersPerRow).ceil();
      debugPrint(
          '[BarcodePrint] Generated ${stickers.length} sticker widgets. Total pages(rows)=$totalPages');

      // One row per page.
      for (int pageIdx = 0;
          pageIdx < stickers.length;
          pageIdx += safeStickersPerRow) {
        final rowStickers = stickers.sublist(
          pageIdx,
          (pageIdx + safeStickersPerRow).clamp(0, stickers.length),
        );

        final pageNo = (pageIdx ~/ safeStickersPerRow) + 1;
        debugPrint(
            '[BarcodePrint] Building page $pageNo with ${rowStickers.length} sticker(s).');

        if (effectiveRotation == null && !invertPrintColors) {
          // Keep the legacy page construction untouched for existing users.
          pdf.addPage(
            pw.Page(
              pageFormat: pageFormat,
              margin: pw.EdgeInsets.all(pageMargin),
              build: (pw.Context ctx) {
                return pw.Align(
                  alignment: pw.Alignment.topLeft,
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      for (int i = 0; i < rowStickers.length; i++) ...[
                        if (i > 0) pw.SizedBox(width: gap),
                        rowStickers[i].widget,
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        } else {
          final rotatedPageBytes = _buildRotatedBarcodePage(
            stickers: rowStickers,
            pageWidthMm: pageWidth / PdfPageFormat.mm,
            pageHeightMm: pageHeight / PdfPageFormat.mm,
            stickerWidthMm: stickerW / PdfPageFormat.mm,
            stickerHeightMm: stickerH / PdfPageFormat.mm,
            pageMarginMm: pageMargin / PdfPageFormat.mm,
            gapMm: gap / PdfPageFormat.mm,
            dpi: layoutSettings.rasterDpi,
            rotationDegrees: effectiveRotation ?? 0,
            invertPrintColors: invertPrintColors,
          );
          pdf.addPage(
            pw.Page(
              pageFormat: printPageFormat,
              margin: pw.EdgeInsets.zero,
              build: (pw.Context ctx) => pw.Image(
                pw.MemoryImage(rotatedPageBytes),
                width: printPageFormat.width,
                height: printPageFormat.height,
              ),
            ),
          );
        }
      }

      // Save PDF
      final output = await _getEposDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${output.path}/barcodes_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint(
          '[BarcodePrint] PDF saved to: ${file.path} (${(await file.length())} bytes)');

      hideLoadingOverlay();

      if (Platform.isWindows) {
        return _handleWindowsPdf(
          file,
          pageFormat: printPageFormat,
          stickerSize: stickerSize,
          stickersPerRow: safeStickersPerRow,
          totalPages: totalPages,
        );
      }

      try {
        final result = await OpenFile.open(file.path);
        if (result.type == ResultType.done) {
          if (context.mounted) {
            showScaffold(context: context, message: 'Barcode PDF opened');
          }
          return const BarcodePrintResult(
            BarcodePrintStatus.pdfOpened,
            'Barcode PDF opened',
          );
        }
        return _sharePdfFallback(file);
      } catch (error) {
        debugPrint('[BarcodePrint] Opening PDF failed: $error');
        return _sharePdfFallback(file);
      }
    } catch (e, stackTrace) {
      hideLoadingOverlay();
      debugPrint("ERROR generating Barcode PDF: $e");
      debugPrint("Stack trace: $stackTrace");
      debugPrint('========== BARCODE PRINT DEBUG END (ERROR) ==========');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: $e",
        );
      }
      return BarcodePrintResult(
        BarcodePrintStatus.failed,
        'Error generating PDF: $e',
      );
    }
  }

  // Handle Windows PDF printing — tries silent direct print first, then falls back to dialog
  Future<BarcodePrintResult> _handleWindowsPdf(
    File file, {
    required PdfPageFormat pageFormat,
    required String stickerSize,
    required int stickersPerRow,
    required int totalPages,
  }) async {
    debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf START ──');

    // Normalize path to use backslashes (Documents dir returns mixed slashes on Windows)
    final winPath = file.path.replaceAll('/', '\\');
    debugPrint('[BarcodePrint:Windows] PDF path (normalized): $winPath');
    debugPrint('[BarcodePrint:Windows] PDF exists: ${await file.exists()}');
    debugPrint('[BarcodePrint:Windows] PDF size: ${await file.length()} bytes');
    debugPrint(
        '[BarcodePrint:Windows] Sticker size: $stickerSize, stickers/row: $stickersPerRow, total pages: $totalPages');
    debugPrint(
        '[BarcodePrint:Windows] Page format: ${(pageFormat.width / PdfPageFormat.mm).toStringAsFixed(2)}mm x ${(pageFormat.height / PdfPageFormat.mm).toStringAsFixed(2)}mm');

    final savedPrinter = await _loadSelectedBarcodePrinter();
    final printerName = savedPrinter?.deviceName?.trim() ?? '';
    debugPrint(
        '[BarcodePrint:Windows] Saved printer name: "${printerName.isEmpty ? "(none saved)" : printerName}"');
    debugPrint(
        '[BarcodePrint:Windows] Saved printer type: ${savedPrinter?.typePrinter}');
    debugPrint(
        '[BarcodePrint:Windows] Saved printer address: ${savedPrinter?.address ?? "(none)"}');

    if (printerName.isNotEmpty) {
      // Strategy 0: printing package — native Windows print spooler, no external viewer needed
      debugPrint(
          '[BarcodePrint:Windows] Strategy 0: Trying Printing.directPrintPdf...');
      try {
        final pdfBytes = await file.readAsBytes();
        final printers = await Printing.listPrinters();
        debugPrint(
            '[BarcodePrint:Windows]   System printers (${printers.length}):');
        for (final p in printers) {
          debugPrint(
              '[BarcodePrint:Windows]     - "${p.name}" | default=${p.isDefault} | available=${p.isAvailable} | url=${p.url}');
        }
        final savedUrl = savedPrinter?.address?.trim() ?? '';
        final matches = printers.where((printer) {
          final urlMatches = savedUrl.isNotEmpty && printer.url == savedUrl;
          final nameMatches =
              printer.name.toLowerCase() == printerName.toLowerCase();
          return urlMatches || nameMatches;
        }).toList();
        if (matches.isEmpty) {
          throw StateError('Configured printer is not available');
        }
        final targetPrinter = matches.first;
        if (!targetPrinter.isAvailable) {
          throw StateError('Configured printer is offline');
        }
        debugPrint(
            '[BarcodePrint:Windows]   Selected printer: "${targetPrinter.name}" | default=${targetPrinter.isDefault} | available=${targetPrinter.isAvailable}');
        debugPrint(
            '[BarcodePrint:Windows]   Sending ${pdfBytes.length} bytes to spooler...');
        debugPrint(
            '[BarcodePrint:Windows]   Page format hint: ${(pageFormat.width / PdfPageFormat.mm).toStringAsFixed(2)}mm x ${(pageFormat.height / PdfPageFormat.mm).toStringAsFixed(2)}mm');
        final success = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (_) async => pdfBytes,
          name: 'Barcodes',
          format: pageFormat,
          dynamicLayout: false,
          usePrinterSettings: true,
        );
        debugPrint('[BarcodePrint:Windows]   directPrintPdf result: $success');
        if (success) {
          if (context.mounted) {
            showScaffold(
                context: context,
                message: 'Sent to printer: ${targetPrinter.name}');
          }
          debugPrint(
              '[BarcodePrint:Windows] ── _handleWindowsPdf END (printing pkg) ──');
          return BarcodePrintResult(
            BarcodePrintStatus.sentToPrinter,
            'Sent to printer: ${targetPrinter.name}',
          );
        }
        debugPrint(
            '[BarcodePrint:Windows]   printing pkg returned false, trying next strategy...');
      } catch (e) {
        debugPrint(
            '[BarcodePrint:Windows]   printing pkg failed: $e, trying next strategy...');
      }

      // Strategy 1: SumatraPDF — free PDF viewer with excellent CLI, common in business setups
      // Command: SumatraPDF.exe -print-to "printer name" -silent file.pdf
      final sumatraPaths = [
        r'C:\Program Files\SumatraPDF\SumatraPDF.exe',
        r'C:\Program Files (x86)\SumatraPDF\SumatraPDF.exe',
        '${Platform.environment['LOCALAPPDATA'] ?? ''}/SumatraPDF/SumatraPDF.exe',
        '${Platform.environment['APPDATA'] ?? ''}/SumatraPDF/SumatraPDF.exe',
      ];
      debugPrint('[BarcodePrint:Windows] Strategy 1: Trying SumatraPDF...');
      for (final path in sumatraPaths) {
        final normalized = path.replaceAll('/', '\\');
        debugPrint('[BarcodePrint:Windows]   Checking: $normalized');
        if (await File(normalized).exists()) {
          debugPrint(
              '[BarcodePrint:Windows]   ✅ Found SumatraPDF at: $normalized');
          final result = await Process.run(
              normalized, ['-print-to', printerName, '-silent', winPath]);
          debugPrint(
              '[BarcodePrint:Windows]   SumatraPDF exit code: ${result.exitCode}');
          if ((result.stderr as String).isNotEmpty) {
            debugPrint(
                '[BarcodePrint:Windows]   SumatraPDF stderr: ${result.stderr}');
          }
          if (result.exitCode == 0) {
            if (context.mounted) {
              showScaffold(
                  context: context, message: 'Sent to printer: $printerName');
            }
            debugPrint(
                '[BarcodePrint:Windows] ── _handleWindowsPdf END (SumatraPDF) ──');
            return BarcodePrintResult(
              BarcodePrintStatus.sentToPrinter,
              'Sent to printer: $printerName',
            );
          }
          debugPrint(
              '[BarcodePrint:Windows]   SumatraPDF failed, trying next strategy...');
          break;
        }
      }
      debugPrint('[BarcodePrint:Windows]   SumatraPDF not found.');

      // Strategy 2: Adobe Reader / Acrobat — common enterprise PDF viewer
      // Command: AcroRd32.exe /t "file.pdf" "printer name"
      final adobePaths = [
        r'C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe',
        r'C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe',
        r'C:\Program Files (x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe',
        r'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe',
        r'C:\Program Files (x86)\Adobe\Reader 11.0\Reader\AcroRd32.exe',
      ];
      debugPrint(
          '[BarcodePrint:Windows] Strategy 2: Trying Adobe Reader/Acrobat...');
      for (final path in adobePaths) {
        debugPrint('[BarcodePrint:Windows]   Checking: $path');
        if (await File(path).exists()) {
          debugPrint('[BarcodePrint:Windows]   ✅ Found Adobe at: $path');
          final result = await Process.run(path, ['/t', winPath, printerName]);
          debugPrint(
              '[BarcodePrint:Windows]   Adobe exit code: ${result.exitCode}');
          if ((result.stderr as String).isNotEmpty) {
            debugPrint(
                '[BarcodePrint:Windows]   Adobe stderr: ${result.stderr}');
          }
          if (result.exitCode == 0) {
            if (context.mounted) {
              showScaffold(
                  context: context, message: 'Sent to printer: $printerName');
            }
            debugPrint(
                '[BarcodePrint:Windows] ── _handleWindowsPdf END (Adobe) ──');
            return BarcodePrintResult(
              BarcodePrintStatus.sentToPrinter,
              'Sent to printer: $printerName',
            );
          }
          debugPrint(
              '[BarcodePrint:Windows]   Adobe failed, trying next strategy...');
          break;
        }
      }
      debugPrint('[BarcodePrint:Windows]   Adobe Reader/Acrobat not found.');
    }

    // Strategy 3: Print dialog via Windows shell Print verb
    // Edge (always on Windows 10/11) handles this and shows a print dialog
    debugPrint(
        '[BarcodePrint:Windows] Strategy 3: Opening print dialog via shell Print verb...');
    final escapedWinPath = winPath.replaceAll("'", "''");
    final psCmd = "Start-Process -FilePath '$escapedWinPath' -Verb Print";
    debugPrint('[BarcodePrint:Windows]   PowerShell: $psCmd');
    final dialogResult = await Process.run('powershell', ['-command', psCmd]);
    debugPrint(
        '[BarcodePrint:Windows]   Print dialog exit code: ${dialogResult.exitCode}');
    if ((dialogResult.stderr as String).isNotEmpty) {
      debugPrint(
          '[BarcodePrint:Windows]   Print dialog stderr: ${dialogResult.stderr}');
    }

    if (dialogResult.exitCode == 0) {
      if (context.mounted) {
        showScaffold(context: context, message: 'Print dialog opened');
      }
      debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf END (dialog) ──');
      return const BarcodePrintResult(
        BarcodePrintStatus.pdfOpened,
        'Print dialog opened',
      );
    }

    // Strategy 4: Last resort — just open the file in the default PDF viewer
    debugPrint(
        '[BarcodePrint:Windows] ⚠️ All print strategies failed. Falling back to open.');
    final openResult = await OpenFile.open(winPath);
    if (openResult.type == ResultType.done) {
      if (context.mounted) {
        showScaffold(context: context, message: 'Barcode PDF opened');
      }
      return const BarcodePrintResult(
        BarcodePrintStatus.pdfOpened,
        'Barcode PDF opened',
      );
    }
    final message = 'PDF saved but could not be opened: ${file.path}';
    if (context.mounted) {
      showScaffoldError(context: context, message: message);
    }
    debugPrint(
        '[BarcodePrint:Windows] ── _handleWindowsPdf END (open fallback) ──');
    return BarcodePrintResult(BarcodePrintStatus.failed, message);
  }

  // Fallback to sharing PDF
  Future<BarcodePrintResult> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      if (!Platform.isWindows) {
        // ignore: deprecated_member_use
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Barcode Stickers',
          text: 'Barcode Stickers PDF',
        );
        if (result.status == ShareResultStatus.success) {
          if (context.mounted) {
            showScaffold(context: context, message: "PDF shared");
          }
          return const BarcodePrintResult(
            BarcodePrintStatus.pdfShared,
            'Barcode PDF shared',
          );
        }
        final message = 'PDF saved: ${file.path}';
        if (context.mounted) {
          showScaffold(context: context, message: message);
        }
        return BarcodePrintResult(BarcodePrintStatus.pdfSaved, message);
      } else {
        final message = 'PDF saved: ${file.path}';
        if (context.mounted) {
          showScaffold(context: context, message: message);
        }
        return BarcodePrintResult(BarcodePrintStatus.pdfSaved, message);
      }
    } catch (e) {
      debugPrint("Error sharing PDF: $e");
      final message = 'PDF saved but could not be shared: ${file.path}';
      if (context.mounted) {
        showScaffoldError(context: context, message: message);
      }
      return BarcodePrintResult(BarcodePrintStatus.failed, message);
    }
  }
}
