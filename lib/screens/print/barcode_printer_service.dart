import 'dart:convert';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/screens/product/widgets/confirm_barcode_print_modal.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Cache for fonts
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  Future<pw.Font> _loadRegularFont() async {
    if (_regularFont != null) return _regularFont!;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _regularFont = pw.Font.ttf(fontData);
      return _regularFont!;
    } catch (e) {
      debugPrint('Error loading font: $e');
      rethrow;
    }
  }

  Future<pw.Font> _loadBoldFont() async {
    if (_boldFont != null) return _boldFont!;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _boldFont = pw.Font.ttf(fontData);
      return _boldFont!;
    } catch (e) {
      debugPrint('Error loading bold font: $e');
      rethrow;
    }
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

  Future<void> _connectToPrinter(
    PrinterManager printerManager,
    BluetoothPrinter printer,
  ) async {
    if (printer.typePrinter == PrinterType.usb) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: printer.deviceName ?? 'Unknown',
          productId: printer.productId,
          vendorId: printer.vendorId,
        ),
      );
      return;
    }

    if (printer.address == null || printer.address!.trim().isEmpty) {
      throw Exception('Bluetooth printer address is missing');
    }

    await printerManager.connect(
      type: PrinterType.bluetooth,
      model: BluetoothPrinterInput(
        name: printer.deviceName ?? 'Unknown',
        address: printer.address!,
        isBle: false,
      ),
    );
  }

  Future<void> _disconnectPrinter(
    PrinterManager printerManager,
    BluetoothPrinter printer,
  ) async {
    try {
      await printerManager.disconnect(type: printer.typePrinter);
    } catch (e) {
      debugPrint('[BarcodePrint] Printer disconnect error: $e');
    }
  }

  String _sanitizeForThermal(String input) {
    return input
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('…', '...');
  }


  /// Returns a Latin1-safe product name for ESC/POS thermal printing.
  /// If the resolved name contains any non-Latin1 character (codeUnit > 255),
  /// falls back to the English name, then productName field, then empty string.
  String _toThermalSafe(String resolved, GetProduct product) {
    final hasNonLatin1 = resolved.codeUnits.any((c) => c > 255);
    if (!hasNonLatin1) return resolved;
    // Fallback chain: English translation -> productName field -> empty
    final englishName = _extractTranslatedName(product.names, 'en');
    if (englishName.isNotEmpty) return englishName;
    final fallback = (product.productName ?? '').trim();
    return fallback;
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
        return 'en';
    }
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
        final parts = <String>[
          if (englishName.isNotEmpty)
            englishName
          else if (fallbackName.isNotEmpty)
            fallbackName,
          if (arabicName.isNotEmpty) arabicName,
        ];
        return parts.join(' / ');
      case 'ar/en':
        final parts = <String>[
          if (arabicName.isNotEmpty) arabicName,
          if (englishName.isNotEmpty)
            englishName
          else if (fallbackName.isNotEmpty)
            fallbackName,
        ];
        return parts.join(' / ');
      case 'en':
      default:
        return englishName.isNotEmpty
            ? englishName
            : fallbackName.isNotEmpty
                ? fallbackName
                : arabicName;
    }
  }

  Future<bool> _tryDirectPrintToSelectedPrinter({
    required List<BarcodePrintItem> printItems,
    required String stickerSize,
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
      debugPrint('[BarcodePrint] No saved barcode printer found.');
      return false;
    }

    final printerManager = PrinterManager.instance;
    try {
      await _connectToPrinter(printerManager, selectedPrinter);

      final profile = await CapabilityProfile.load();
      final paperSize =
          stickerSize == '91x24mm' ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(paperSize, profile);
      final bytes = <int>[];

      for (final item in printItems) {
        if (item.quantity < 1) continue;

        final product = item.product;
        final barcodeValue = (product.barcode ?? '').trim();
        final productName =
            _sanitizeForThermal(_toThermalSafe(_resolveProductName(product, productNameMode), product));
        final rawPriceText =
            (product.price?.price ?? product.mrp ?? 'N/A').toString().trim();
        final parsedPrice = double.tryParse(rawPriceText);
        final priceToShow =
            parsedPrice != null ? parsedPrice.toStringAsFixed(2) : rawPriceText;

        String dateLine = '';
        if (showMfgDate && item.mfgDate != null) {
          dateLine +=
              'PKG:${DateFormat('"' "'dd-MM-yy'" '"').format(item.mfgDate!)}';
        }
        if (showExpiryDate && item.expDate != null) {
          if (dateLine.isNotEmpty) {
            dateLine += ' ';
          }
          dateLine +=
              'EXD:${DateFormat('"' "'dd-MM-yy'" '"').format(item.expDate!)}';
        }

        for (int i = 0; i < item.quantity; i++) {
          if (showStoreName && storeName.isNotEmpty) {
            bytes.addAll(generator.text(
              _sanitizeForThermal(storeName),
              styles: const PosStyles(
                align: PosAlign.center,
                bold: true,
                height: PosTextSize.size1,
              ),
            ));
          }

          if (showProductName && productName.isNotEmpty) {
            bytes.addAll(generator.text(
              productName,
              styles: const PosStyles(
                align: PosAlign.center,
                bold: true,
                height: PosTextSize.size1,
              ),
            ));
          }

          if (showPrice) {
            bytes.addAll(generator.text(
              '$currency $priceToShow',
              styles: const PosStyles(
                align: PosAlign.center,
                bold: true,
                height: PosTextSize.size1,
              ),
            ));
          }

          if (barcodeValue.isNotEmpty) {
            try {
              final code39Data = barcodeValue
                  .toUpperCase()
                  .replaceAll(RegExp(r'[^A-Z0-9\-\. \$\/+%]'), '')
                  .split('');
              if (code39Data.isNotEmpty) {
                bytes.addAll(generator.barcode(
                  Barcode.code39(code39Data),
                  height: 35,
                  width: 1,
                  textPos: BarcodeText.none,
                  align: PosAlign.center,
                ));
              }
            } catch (e) {
              debugPrint(
                  '[BarcodePrint] Barcode render failed for ESC/POS: $e');
            }

            if (showBarcodeNumber) {
              bytes.addAll(generator.text(
                _sanitizeForThermal(barcodeValue),
                styles: const PosStyles(align: PosAlign.center),
              ));
            }
          }

          if (dateLine.isNotEmpty) {
            bytes.addAll(generator.text(
              _sanitizeForThermal(dateLine),
              styles: const PosStyles(
                align: PosAlign.center,
                bold: true,
                height: PosTextSize.size1,
              ),
            ));
          }

          bytes.addAll(generator.hr(ch: '-'));
        }
      }

      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());

      await printerManager.send(
        type: selectedPrinter.typePrinter,
        bytes: bytes,
      );

      debugPrint(
        '[BarcodePrint] Direct print sent to ${selectedPrinter.deviceName ?? '"' "'Unknown printer'" '"'}',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('[BarcodePrint] Direct print failed: $e');
      debugPrint('[BarcodePrint] Direct print stack: $stackTrace');
      return false;
    } finally {
      await _disconnectPrinter(printerManager, selectedPrinter);
    }
  }

  /// Generate a barcode sticker PDF and open/share it.
  Future<void> printBarcodes({
    required List<BarcodePrintItem> printItems,
    String stickerSize = '50x25mm',
    int stickersPerRow = 1,
  }) async {
    if (printItems.isEmpty) {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'No stocks selected to print.',
        );
      }
      return;
    }

    try {
      debugPrint('========== BARCODE PRINT DEBUG START ==========');
      debugPrint(
          '[BarcodePrint] Request -> items=${printItems.length}, stickerSize=$stickerSize, stickersPerRow=$stickersPerRow');

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

      final showStoreName = readVisible('showStoreName', fallback: false);
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
      final regularFont = await _loadRegularFont();
      final boldFont = await _loadBoldFont();

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

      final double nameFontSize = layoutSettings.productNameFontSize;
      final double storeNameFontSize = layoutSettings.storeNameFontSize;
      final double priceFontSize = layoutSettings.priceFontSize;
      final double dateFontSize = layoutSettings.dateFontSize;
      final double barcodeFontSize = layoutSettings.barcodeNumberFontSize;
      final double barcodeHeight = layoutSettings.barcodeHeight;
      final double elementSpacing = layoutSettings.elementSpacing;

      final nameStyle = pw.TextStyle(
        font: boldFont,
        fontSize: nameFontSize,
        fontWeight: pw.FontWeight.bold,
      );
      final storeNameStyle = pw.TextStyle(
        font: boldFont,
        fontSize: storeNameFontSize,
        fontWeight: pw.FontWeight.bold,
      );
      final priceStyle = pw.TextStyle(
        font: boldFont,
        fontSize: priceFontSize,
        fontWeight: pw.FontWeight.bold,
      );
      final dateStyle = pw.TextStyle(
        font: boldFont,
        fontSize: dateFontSize,
        fontWeight: pw.FontWeight.bold,
      );
      final barcodeTextStyle = pw.TextStyle(
        font: regularFont,
        fontSize: barcodeFontSize,
      );

      final pdf = pw.Document();

      final int safeStickersPerRow = stickersPerRow < 1 ? 1 : stickersPerRow;
      final double pageMargin = layoutSettings.pageMargin * PdfPageFormat.mm;
      final double gap = layoutSettings.stickerGap * PdfPageFormat.mm;
      final double rowWidth =
          (safeStickersPerRow * stickerW) + ((safeStickersPerRow - 1) * gap);
      final double pageWidth = rowWidth + (pageMargin * 2);
      final double pageHeight = stickerH + (pageMargin * 2);
      final pageFormat = PdfPageFormat(pageWidth, pageHeight);

      debugPrint(
          '[BarcodePrint] Sticker(mm) -> width=${(stickerW / PdfPageFormat.mm).toStringAsFixed(2)}, height=${(stickerH / PdfPageFormat.mm).toStringAsFixed(2)}');
      debugPrint(
          '[BarcodePrint] Page(mm) -> width=${(pageWidth / PdfPageFormat.mm).toStringAsFixed(2)}, height=${(pageHeight / PdfPageFormat.mm).toStringAsFixed(2)}, rowWidth=${(rowWidth / PdfPageFormat.mm).toStringAsFixed(2)}, margin=${(pageMargin / PdfPageFormat.mm).toStringAsFixed(2)}, gap=${(gap / PdfPageFormat.mm).toStringAsFixed(2)}');

      // Build flat list of sticker widgets respecting quantity
      final List<pw.Widget> stickers = [];
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
        }

        for (int i = 0; i < item.quantity; i++) {
          stickers.add(_buildSticker(
            item: item,
            stickerW: stickerW,
            stickerH: stickerH,
            nameStyle: nameStyle,
            storeNameStyle: storeNameStyle,
            priceStyle: priceStyle,
            dateStyle: dateStyle,
            barcodeTextStyle: barcodeTextStyle,
            barcodeHeight: barcodeHeight,
            elementSpacing: elementSpacing,
            storeName: storeName,
            currency: currency,
            showStoreName: showStoreName,
            showProductName: showProductName,
            productNameMode: productNameMode,
            showPrice: showPrice,
            showBarcodeNumber: showBarcodeNumber,
            showMfgDate: showMfgDate,
            showExpiryDate: showExpiryDate,
          ));
        }
      }

      final totalPages = safeStickersPerRow == 0
          ? 0
          : (stickers.length / safeStickersPerRow).ceil();
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

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(pageMargin),
            build: (pw.Context ctx) {
              return pw.Align(
                alignment: pw.Alignment.topCenter,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: rowStickers.map((s) {
                    return pw.Padding(
                      padding: pw.EdgeInsets.only(right: gap),
                      child: s,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      }

      // Save PDF
      final output = await _getEposDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${output.path}/barcodes_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint('[BarcodePrint] PDF saved to: ${file.path} (${(await file.length())} bytes)');

      hideLoadingOverlay();

      if (Platform.isWindows) {
        await _handleWindowsPdf(file, pageFormat: pageFormat, stickerSize: stickerSize, stickersPerRow: safeStickersPerRow, totalPages: totalPages);
      } else {
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(context: context, message: 'Barcode PDF opened');
            }
          }
        } catch (e) {
          await _sharePdfFallback(file);
        }
      }

      debugPrint('Barcode PDF generation complete!');
      debugPrint('========== BARCODE PRINT DEBUG END ==========');
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
    }
  }

  /// Build a single sticker widget
  pw.Widget _buildSticker({
    required BarcodePrintItem item,
    required double stickerW,
    required double stickerH,
    required pw.TextStyle nameStyle,
    required pw.TextStyle storeNameStyle,
    required pw.TextStyle priceStyle,
    required pw.TextStyle dateStyle,
    required pw.TextStyle barcodeTextStyle,
    required double barcodeHeight,
    required double elementSpacing,
    required String storeName,
    required String currency,
    required bool showStoreName,
    required bool showProductName,
    required String productNameMode,
    required bool showPrice,
    required bool showBarcodeNumber,
    required bool showMfgDate,
    required bool showExpiryDate,
  }) {
    final product = item.product;
    final productName = _resolveProductName(product, productNameMode);
    // Format price to 2 decimal places
    final rawPriceText =
        (product.price?.price ?? product.mrp ?? 'N/A').toString().trim();
    final parsedPrice = double.tryParse(rawPriceText);
    final priceToShow =
        parsedPrice != null ? parsedPrice.toStringAsFixed(2) : rawPriceText;

    // Date format matching user reference: P:dd/MM/yyyy E:dd/MM/yyyy
    String dateLine = '';
    if (showMfgDate && item.mfgDate != null) {
      dateLine += "P:${DateFormat('dd/MM/yyyy').format(item.mfgDate!)}";
    }
    if (showExpiryDate && item.expDate != null) {
      if (dateLine.isNotEmpty) dateLine += ' ';
      dateLine += "E:${DateFormat('dd/MM/yyyy').format(item.expDate!)}";
    }

    // Use FittedBox with BoxFit.contain to fill width SAFELY without clipping
    return pw.Container(
      width: stickerW,
      height: stickerH,
      padding: const pw.EdgeInsets.all(0.5),
      child: pw.FittedBox(
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.center,
        child: pw.SizedBox(
          width: stickerW,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Name
              if (showStoreName && storeName.isNotEmpty) ...[
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    storeName,
                    style: storeNameStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: elementSpacing),
              ],

              // Barcode graphic + number
              if (product.barcode != null && product.barcode!.isNotEmpty) ...[
                pw.SizedBox(
                  width: stickerW * 0.98, // Fill width
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: product.barcode!,
                    height: barcodeHeight,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(height: elementSpacing / 2),
                if (showBarcodeNumber) ...[
                  pw.Text(
                    product.barcode!,
                    style: barcodeTextStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: elementSpacing),
                ],
              ],

              // Price
              if (showPrice) ...[
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '$currency $priceToShow',
                    style: priceStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: elementSpacing),
              ],

              // Product Name
              if (showProductName && productName.isNotEmpty) ...[
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    productName,
                    style: nameStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: elementSpacing),
              ],

              // MFG / EXP date
              if (dateLine.isNotEmpty)
                pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    dateLine,
                    style: dateStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle Windows PDF printing — tries silent direct print first, then falls back to dialog
  Future<void> _handleWindowsPdf(
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
    debugPrint('[BarcodePrint:Windows] Sticker size: $stickerSize, stickers/row: $stickersPerRow, total pages: $totalPages');
    debugPrint('[BarcodePrint:Windows] Page format: ${(pageFormat.width / PdfPageFormat.mm).toStringAsFixed(2)}mm x ${(pageFormat.height / PdfPageFormat.mm).toStringAsFixed(2)}mm');

    final savedPrinter = await _loadSelectedBarcodePrinter();
    final printerName = savedPrinter?.deviceName?.trim() ?? '';
    debugPrint('[BarcodePrint:Windows] Saved printer name: "${printerName.isEmpty ? "(none saved)" : printerName}"');
    debugPrint('[BarcodePrint:Windows] Saved printer type: ${savedPrinter?.typePrinter}');
    debugPrint('[BarcodePrint:Windows] Saved printer address: ${savedPrinter?.address ?? "(none)"}');

    if (printerName.isNotEmpty) {
      // Strategy 0: printing package — native Windows print spooler, no external viewer needed
      debugPrint('[BarcodePrint:Windows] Strategy 0: Trying Printing.directPrintPdf...');
      try {
        final pdfBytes = await file.readAsBytes();
        final printers = await Printing.listPrinters();
        debugPrint('[BarcodePrint:Windows]   System printers (${printers.length}):');
        for (final p in printers) {
          debugPrint('[BarcodePrint:Windows]     - "${p.name}" | default=${p.isDefault} | available=${p.isAvailable} | url=${p.url}');
        }
        final targetPrinter = printers.firstWhere(
          (p) => p.name.toLowerCase() == printerName.toLowerCase(),
          orElse: () => printers.firstWhere(
            (p) => p.name.toLowerCase().contains(printerName.toLowerCase()),
            orElse: () => printers.isEmpty ? throw Exception('No printers') : printers.first,
          ),
        );
        debugPrint('[BarcodePrint:Windows]   Selected printer: "${targetPrinter.name}" | default=${targetPrinter.isDefault} | available=${targetPrinter.isAvailable}');
        debugPrint('[BarcodePrint:Windows]   Sending ${pdfBytes.length} bytes to spooler...');
        debugPrint('[BarcodePrint:Windows]   Page format hint: ${(pageFormat.width / PdfPageFormat.mm).toStringAsFixed(2)}mm x ${(pageFormat.height / PdfPageFormat.mm).toStringAsFixed(2)}mm');
        final success = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (_) async => pdfBytes,
          name: 'Barcodes',
          format: pageFormat,
        );
        debugPrint('[BarcodePrint:Windows]   directPrintPdf result: $success');
        if (success) {
          if (context.mounted) showScaffold(context: context, message: 'Sent to printer: ${targetPrinter.name}');
          debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf END (printing pkg) ──');
          return;
        }
        debugPrint('[BarcodePrint:Windows]   printing pkg returned false, trying next strategy...');
      } catch (e) {
        debugPrint('[BarcodePrint:Windows]   printing pkg failed: $e, trying next strategy...');
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
          debugPrint('[BarcodePrint:Windows]   ✅ Found SumatraPDF at: $normalized');
          final result = await Process.run(normalized, ['-print-to', printerName, '-silent', winPath]);
          debugPrint('[BarcodePrint:Windows]   SumatraPDF exit code: ${result.exitCode}');
          if ((result.stderr as String).isNotEmpty) debugPrint('[BarcodePrint:Windows]   SumatraPDF stderr: ${result.stderr}');
          if (result.exitCode == 0) {
            if (context.mounted) showScaffold(context: context, message: 'Sent to printer: $printerName');
            debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf END (SumatraPDF) ──');
            return;
          }
          debugPrint('[BarcodePrint:Windows]   SumatraPDF failed, trying next strategy...');
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
      debugPrint('[BarcodePrint:Windows] Strategy 2: Trying Adobe Reader/Acrobat...');
      for (final path in adobePaths) {
        debugPrint('[BarcodePrint:Windows]   Checking: $path');
        if (await File(path).exists()) {
          debugPrint('[BarcodePrint:Windows]   ✅ Found Adobe at: $path');
          final result = await Process.run(path, ['/t', winPath, printerName]);
          debugPrint('[BarcodePrint:Windows]   Adobe exit code: ${result.exitCode}');
          if ((result.stderr as String).isNotEmpty) debugPrint('[BarcodePrint:Windows]   Adobe stderr: ${result.stderr}');
          if (result.exitCode == 0) {
            if (context.mounted) showScaffold(context: context, message: 'Sent to printer: $printerName');
            debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf END (Adobe) ──');
            return;
          }
          debugPrint('[BarcodePrint:Windows]   Adobe failed, trying next strategy...');
          break;
        }
      }
      debugPrint('[BarcodePrint:Windows]   Adobe Reader/Acrobat not found.');
    }

    // Strategy 3: Print dialog via Windows shell Print verb
    // Edge (always on Windows 10/11) handles this and shows a print dialog
    debugPrint('[BarcodePrint:Windows] Strategy 3: Opening print dialog via shell Print verb...');
    final psCmd = "Start-Process -FilePath '$winPath' -Verb Print";
    debugPrint('[BarcodePrint:Windows]   PowerShell: $psCmd');
    final dialogResult = await Process.run('powershell', ['-command', psCmd]);
    debugPrint('[BarcodePrint:Windows]   Print dialog exit code: ${dialogResult.exitCode}');
    if ((dialogResult.stderr as String).isNotEmpty) debugPrint('[BarcodePrint:Windows]   Print dialog stderr: ${dialogResult.stderr}');

    if (dialogResult.exitCode == 0) {
      if (context.mounted) showScaffold(context: context, message: 'Print dialog opened');
      debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf END (dialog) ──');
      return;
    }

    // Strategy 4: Last resort — just open the file in the default PDF viewer
    debugPrint('[BarcodePrint:Windows] ⚠️ All print strategies failed. Falling back to open.');
    await Process.run('cmd', ['/c', 'start', '', winPath]);
    if (context.mounted) showScaffold(context: context, message: 'Barcode PDF opened');
    debugPrint('[BarcodePrint:Windows] ── _handleWindowsPdf END (open fallback) ──');
  }

  // Fallback to sharing PDF
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      if (!Platform.isWindows) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Barcode Stickers',
          text: 'Barcode Stickers PDF',
        );
        if (context.mounted) {
          showScaffold(context: context, message: "PDF shared");
        }
      } else {
        if (context.mounted) {
          showScaffold(context: context, message: "PDF saved: ${file.path}");
        }
      }
    } catch (e) {
      debugPrint("Error sharing PDF: $e");
      if (context.mounted) {
        showScaffold(context: context, message: "PDF saved: ${file.path}");
      }
    }
  }
}
