import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

/// Kitchen Order Ticket (KOT) Printer using Document Configuration
/// Prints: Order number, Table, Time, Items (qty + name), Comment
/// Uses display_configuration and resolved_labels from API
/// Supports responsive layouts for both 80mm and 58mm thermal paper
class KotThermalPrinter {
  final BuildContext context;
  var printerManager = PrinterManager.instance;

  // =========================================================
  // RESPONSIVE SIZING SYSTEM
  // =========================================================
  // 58mm: narrower paper (384px) needs smaller fonts and tighter spacing
  // 80mm: wider paper (576px) allows for larger fonts and better readability

  /// Print width in pixels for each paper size
  static double getPrintWidth(bool is58mm) => is58mm ? 384.0 : 576.0;

  /// Get base font size based on paper size
  static double getBaseFontSize(bool is58mm) => is58mm ? 20.0 : 20.0;

  /// Get header font scale (for Kitchen Order title)
  static double getHeaderScale(bool is58mm) => is58mm ? 1.5 : 2.2;

  /// Get table/order info scale (prominent info like table number)
  static double getTableScale(bool is58mm) => is58mm ? 1.3 : 1.8;

  /// Get order number scale
  static double getOrderScale(bool is58mm) => is58mm ? 1.0 : 1.3;

  /// Get item font scale (item names - needs to be readable)
  static double getItemScale(bool is58mm) => is58mm ? 1.0 : 1.3;

  /// Get quantity font scale (bold large numbers)
  static double getQtyScale(bool is58mm) => is58mm ? 1.1 : 1.5;

  /// Get secondary text scale (labels, time, notes)
  static double getSecondaryScale(bool is58mm) => is58mm ? 0.9 : 1.0;

  /// Get small text scale (MRP/Rate info)
  static double getSmallScale(bool is58mm) => is58mm ? 0.75 : 0.85;

  /// Get line height multiplier
  static double getLineHeight(bool is58mm) => is58mm ? 1.15 : 1.25;

  /// Get horizontal padding
  static double getPadding(bool is58mm) => is58mm ? 4.0 : 8.0;

  /// Get spacing between sections
  static double getSectionSpacing(bool is58mm) => is58mm ? 6.0 : 10.0;

  /// Get item spacing (between each item)
  static double getItemSpacing(bool is58mm) => is58mm ? 4.0 : 6.0;

  /// Get divider font scale
  static double getDividerScale(bool is58mm) => is58mm ? 0.8 : 0.7;

  /// Get quantity column width (fixed for alignment)
  static double getQtyColumnWidth(bool is58mm) => is58mm ? 60.0 : 70.0;

  KotThermalPrinter(this.context);

  /// Connect to thermal printer (supports both Bluetooth and USB)
  Future<void> _connectToPrinter(BluetoothPrinter printer) async {
    try {
      if (printer.typePrinter == PrinterType.usb) {
        await printerManager.connect(
          type: PrinterType.usb,
          model: UsbPrinterInput(
            name: printer.deviceName ?? 'Unknown',
            productId: printer.productId,
            vendorId: printer.vendorId,
          ),
        );
      } else if (printer.typePrinter == PrinterType.bluetooth) {
        if (printer.address == null) {
          throw Exception('Bluetooth printer address is null');
        }
        await printerManager.connect(
          type: PrinterType.bluetooth,
          model: BluetoothPrinterInput(
            name: printer.deviceName ?? 'Unknown',
            address: printer.address!,
            isBle: false,
            autoConnect: false,
          ),
        );
      } else {
        throw Exception('Unsupported printer type: ${printer.typePrinter}');
      }
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      rethrow;
    }
  }

  /// Print Kitchen Order Ticket using document configuration
  Future<void> printKot({
    required BluetoothPrinter selectedPrinter,
    required String orderNumber,
    required String tableName,
    required String orderTime,
    required List<Map<String, dynamic>> items,
    String? comment,
    required String selectedPaperSize,
    DocumentConfig? kotDocumentConfig,
  }) async {
    debugPrint("===== KOT THERMAL PRINTING ====");
    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: $selectedPaperSize");
    debugPrint(
        "Document Config: ${kotDocumentConfig != null ? 'Loaded' : 'Not loaded'}");

    try {
      debugPrint("Connecting to printer...");
      await _connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully.");

      final bool is58mm = selectedPaperSize == '58mm';
      final double printWidth = getPrintWidth(is58mm);

      // Get display configuration and labels
      final displayConfig = kotDocumentConfig?.displayConfiguration?.options;
      final resolvedLabels = kotDocumentConfig?.resolvedLabels;

      // Build KOT receipt rows with responsive sizing
      List<_KotRow> rows = [];

      // ========== HEADER SECTION ==========
      final showStoreName = displayConfig?['showStoreName']?.visible ?? true;
      if (showStoreName) {
        final headerText =
            (displayConfig?['showStoreName']?.value as String?)?.isNotEmpty ==
                    true
                ? displayConfig!['showStoreName']!.value as String
                : (kotDocumentConfig?.header?.isNotEmpty == true
                    ? kotDocumentConfig!.header!
                    : 'KITCHEN ORDER');
        rows.add(_KotTextRow(
          headerText.toUpperCase(),
          isBold: true,
          scale: getHeaderScale(is58mm),
          center: true,
        ));
        rows.add(_KotSpacingRow(getSectionSpacing(is58mm)));
      }
      rows.add(_KotDividerRow(char: '═'));

      // ========== ORDER INFO SECTION ==========
      final showOrderNumber =
          displayConfig?['showOrderNumber']?.visible ?? true;
      final showTableNumber =
          displayConfig?['showTableNumber']?.visible ?? true;
      final showDateTime = displayConfig?['showDateTime']?.visible ?? true;

      // Get dynamic labels
      final orderLabel =
          (displayConfig?['showOrderNumber']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showOrderNumber']!.value as String
              : (resolvedLabels?.orderNumber?.isNotEmpty == true
                  ? resolvedLabels!.orderNumber!
                  : 'Order #');

      final tableLabel =
          (displayConfig?['showTableNumber']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showTableNumber']!.value as String
              : 'Table';

      final timeLabel =
          (displayConfig?['showDateTime']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showDateTime']!.value as String
              : 'Time';

      rows.add(_KotSpacingRow(getSectionSpacing(is58mm) * 0.5));

      // Table number - MOST PROMINENT (for kitchen staff to quickly identify)
      if (showTableNumber) {
        rows.add(_KotTextRow(
          '$tableLabel: $tableName',
          isBold: true,
          scale: getTableScale(is58mm),
          center: true,
        ));
      }

      // Order number - secondary prominence
      if (showOrderNumber) {
        rows.add(_KotTextRow(
          '$orderLabel$orderNumber',
          isBold: true,
          scale: getOrderScale(is58mm),
          center: true,
        ));
      }

      // Time - smallest in this section
      if (showDateTime) {
        rows.add(_KotTextRow(
          '$timeLabel: $orderTime',
          scale: getSecondaryScale(is58mm),
          center: true,
        ));
      }

      rows.add(_KotSpacingRow(getSectionSpacing(is58mm) * 0.5));
      rows.add(_KotDividerRow(char: '─'));
      rows.add(_KotSpacingRow(getSectionSpacing(is58mm) * 0.5));

      // ========== ITEMS SECTION ==========
      final showSLNumber = displayConfig?['showSLNumber']?.visible ?? false;
      final showQty = displayConfig?['showQty']?.visible ?? true;
      final showParticulars =
          displayConfig?['showParticulars']?.visible ?? true;
      final showMRP = displayConfig?['showMRP']?.visible ?? false;
      final showRate = displayConfig?['showRate']?.visible ?? false;

      // Get labels with priority: displayConfig value > resolvedLabels > default
      final qtyLabel =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (resolvedLabels?.qty?.isNotEmpty == true
                  ? resolvedLabels!.qty!
                  : 'QTY');

      final particularsLabel =
          (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showParticulars']!.value as String
              : (resolvedLabels?.particulars?.isNotEmpty == true
                  ? resolvedLabels!.particulars!
                  : 'ITEM');

      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (resolvedLabels?.mrp?.isNotEmpty == true
                  ? resolvedLabels!.mrp!
                  : 'MRP');

      final rateLabel =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (resolvedLabels?.rate?.isNotEmpty == true
                  ? resolvedLabels!.rate!
                  : 'Rate');

      // Items header row using table layout for better alignment
      if (showQty || showParticulars) {
        List<_KotTableColumn> headerCols = [];
        if (showParticulars) {
          headerCols.add(_KotTableColumn(
            particularsLabel,
            flex: 1,
            isBold: true,
            align: TextAlign.left,
          ));
        }
        if (showQty) {
          headerCols.add(_KotTableColumn(
            qtyLabel,
            width: getQtyColumnWidth(is58mm),
            isBold: true,
            align: TextAlign.center,
          ));
        }
        rows.add(_KotTableRow(headerCols, scale: getSecondaryScale(is58mm)));
      }

      rows.add(_KotDividerRow(char: '─'));

      // Items list - use table layout for ITEM | QTY alignment
      int slNo = 1;
      for (var item in items) {
        final qty = item['quantity']?.toString() ?? '1';
        final name = item['productName']?.toString() ?? 'Unknown';
        final mrp = item['mrp']?.toString() ?? '';
        final rate =
            item['unitPrice']?.toString() ?? item['rate']?.toString() ?? '';

        // Build item name with optional SL number
        String itemName = showSLNumber ? '${slNo++}. $name' : name;

        // Main item row with ITEM | QTY layout
        List<_KotTableColumn> itemCols = [];

        if (showParticulars) {
          itemCols.add(_KotTableColumn(
            itemName,
            flex: 1,
            align: TextAlign.left,
          ));
        }
        if (showQty) {
          itemCols.add(_KotTableColumn(
            qty,
            width: getQtyColumnWidth(is58mm),
            isBold: true,
            align: TextAlign.center,
            // Adjust scale relative to base font size.
            // if base is 20, item scale 1.1 -> 22.
            scale: getQtyScale(is58mm) / getItemScale(is58mm),
          ));
        }

        rows.add(_KotTableRow(itemCols, scale: getItemScale(is58mm)));

        // Add MRP/Rate on separate line if visible (indented)
        if (showMRP || showRate) {
          List<String> priceInfo = [];
          if (showMRP && mrp.isNotEmpty) priceInfo.add('$mrpLabel: $mrp');
          if (showRate && rate.isNotEmpty) priceInfo.add('$rateLabel: $rate');
          if (priceInfo.isNotEmpty) {
            rows.add(_KotTextRow(
              '  ${priceInfo.join('  ')}',
              scale: getSmallScale(is58mm),
              indent: 0,
            ));
          }
        }

        rows.add(_KotSpacingRow(getItemSpacing(is58mm)));
      }

      rows.add(_KotDividerRow(char: '─'));

      // ========== TOTAL SECTION ==========
      final showTotal = displayConfig?['showTotal']?.visible ?? false;
      if (showTotal) {
        final totalLabel =
            (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
                ? displayConfig!['showTotal']!.value as String
                : (resolvedLabels?.total?.isNotEmpty == true
                    ? resolvedLabels!.total!
                    : 'Total');
        rows.add(_KotSpacingRow(getSectionSpacing(is58mm) * 0.5));
        rows.add(_KotTextRow(
          '$totalLabel Items: ${items.length}',
          scale: getSecondaryScale(is58mm),
          isBold: true,
          center: true,
        ));
      }

      // ========== COMMENT/NOTES SECTION ==========
      final showComment = displayConfig?['showComment']?.visible ?? true;
      if (showComment && comment != null && comment.isNotEmpty) {
        final noteLabel =
            (displayConfig?['showComment']?.value as String?)?.isNotEmpty ==
                    true
                ? displayConfig!['showComment']!.value as String
                : 'Note';

        rows.add(_KotSpacingRow(getSectionSpacing(is58mm)));
        rows.add(_KotDividerRow(char: '─'));
        rows.add(_KotSpacingRow(getSectionSpacing(is58mm) * 0.5));

        // Note label
        rows.add(_KotTextRow(
          '📝 $noteLabel:',
          scale: getSecondaryScale(is58mm),
          isBold: true,
        ));

        // Note content (can wrap)
        rows.add(_KotTextRow(
          comment,
          scale: getSecondaryScale(is58mm),
          wrapText: true,
        ));
      }

      // ========== FOOTER ==========
      rows.add(_KotSpacingRow(getSectionSpacing(is58mm)));
      rows.add(_KotDividerRow(char: '═'));
      rows.add(_KotSpacingRow(getSectionSpacing(is58mm) * 3)); // Feed space

      // Render and print
      final image = await _renderKotToImage(rows, printWidth, is58mm);
      await _printImage(image, selectedPaperSize, selectedPrinter.typePrinter);

      debugPrint("KOT printed successfully!");
    } catch (e, stackTrace) {
      debugPrint("ERROR in KOT Print: $e");
      debugPrint("Stacktrace: $stackTrace");
      rethrow;
    }
  }

  Future<img.Image> _renderKotToImage(
      List<_KotRow> rows, double width, bool is58mm) async {
    final double baseFontSize = getBaseFontSize(is58mm);
    final double lineHeight = getLineHeight(is58mm);
    final double padding = getPadding(is58mm);

    // First pass: Calculate total height
    double totalHeight = padding * 2; // Top and bottom padding
    for (var row in rows) {
      totalHeight += _calculateRowHeight(
          row, baseFontSize, lineHeight, width, padding, is58mm);
    }

    // Create recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, totalHeight));

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, totalHeight),
      Paint()..color = Colors.white,
    );

    double yOffset = padding;

    // Second pass: Render each row
    for (var row in rows) {
      yOffset = _renderRow(row, canvas, yOffset, width, baseFontSize,
          lineHeight, padding, is58mm);
    }

    // Convert to image
    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width.toInt(), totalHeight.toInt());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return img.decodeImage(bytes)!;
  }

  double _calculateRowHeight(_KotRow row, double baseFontSize,
      double lineHeight, double width, double padding, bool is58mm) {
    if (row is _KotTextRow) {
      final fontSize = baseFontSize * row.scale;
      if (row.wrapText) {
        // Estimate wrapped lines
        final availableWidth = width - (padding * 2) - row.indent;
        final charsPerLine = (availableWidth / (fontSize * 0.5)).floor();
        final lines = (row.text.length / charsPerLine).ceil().clamp(1, 10);
        return fontSize * lineHeight * lines;
      }
      return fontSize * lineHeight;
    } else if (row is _KotSpacingRow) {
      return row.height;
    } else if (row is _KotDividerRow) {
      return baseFontSize * getDividerScale(is58mm) * lineHeight;
    } else if (row is _KotTableRow) {
      return baseFontSize * row.scale * lineHeight;
    }
    return 0;
  }

  double _renderRow(_KotRow row, Canvas canvas, double yOffset, double width,
      double baseFontSize, double lineHeight, double padding, bool is58mm) {
    if (row is _KotTextRow) {
      final fontSize = baseFontSize * row.scale;
      final textPainter = TextPainter(
        text: TextSpan(
          text: row.text,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: row.isBold ? FontWeight.bold : FontWeight.normal,
            height: row.wrapText ? 1.3 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: row.center ? TextAlign.center : TextAlign.left,
        maxLines: row.wrapText ? null : 1,
      );

      final availableWidth = width - (padding * 2) - row.indent;
      textPainter.layout(maxWidth: availableWidth);

      double xOffset = padding + row.indent;
      if (row.center) {
        xOffset = (width - textPainter.width) / 2;
      }

      textPainter.paint(canvas, Offset(xOffset, yOffset));

      if (row.wrapText) {
        return yOffset + textPainter.height;
      }
      return yOffset + fontSize * lineHeight;
    } else if (row is _KotSpacingRow) {
      return yOffset + row.height;
    } else if (row is _KotDividerRow) {
      final dividerFontSize = baseFontSize * getDividerScale(is58mm);
      final charsNeeded =
          ((width - padding * 2) / (dividerFontSize * 0.5)).floor();
      final dividerText = row.char * charsNeeded;

      final textPainter = TextPainter(
        text: TextSpan(
          text: dividerText,
          style: TextStyle(
            color: Colors.black87,
            fontSize: dividerFontSize,
            letterSpacing: -1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: width);
      textPainter.paint(canvas, Offset(padding / 2, yOffset));

      return yOffset + dividerFontSize * lineHeight;
    } else if (row is _KotTableRow) {
      final fontSize = baseFontSize * row.scale;
      double xOffset = padding;

      // Calculate flex columns total and fixed widths
      double fixedWidth = 0;
      int totalFlex = 0;
      for (var col in row.columns) {
        if (col.width > 0) {
          fixedWidth += col.width;
        } else {
          totalFlex += col.flex;
        }
      }
      final flexWidth =
          (width - padding * 2 - fixedWidth) / (totalFlex > 0 ? totalFlex : 1);

      for (var col in row.columns) {
        final colWidth = col.width > 0 ? col.width : flexWidth * col.flex;
        final colFontSize = fontSize * col.scale;

        final textPainter = TextPainter(
          text: TextSpan(
            text: col.text,
            style: TextStyle(
              color: Colors.black,
              fontSize: colFontSize,
              fontWeight: col.isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: col.align,
          maxLines: 1,
          ellipsis: '…',
        );
        textPainter.layout(maxWidth: colWidth);

        // Calculate x position based on alignment
        double textX = xOffset;
        if (col.align == TextAlign.center) {
          textX = xOffset + (colWidth - textPainter.width) / 2;
        } else if (col.align == TextAlign.right) {
          textX = xOffset + colWidth - textPainter.width;
        }

        textPainter.paint(canvas, Offset(textX, yOffset));
        xOffset += colWidth;
      }

      return yOffset + fontSize * lineHeight;
    }

    return yOffset;
  }

  Future<void> _printImage(
      img.Image image, String paperSize, PrinterType printerType) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80,
      profile,
    );

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.imageRaster(image, align: PosAlign.center);
    bytes += generator.cut();

    await printerManager.send(type: printerType, bytes: bytes);
  }

  /// Load default printer from SharedPreferences
  static Future<BluetoothPrinter?> loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('default_printer_name');
    final address = prefs.getString('default_printer_address');

    if (name != null && address != null) {
      return BluetoothPrinter(
        deviceName: name,
        address: address,
      );
    }
    return null;
  }

  /// Load default paper size from SharedPreferences
  static Future<String> loadDefaultPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default_paper_size') ?? '58mm';
  }
}

// =========================================================
// ROW TYPES FOR KOT LAYOUT
// =========================================================

abstract class _KotRow {}

/// Text row for simple text content
class _KotTextRow extends _KotRow {
  final String text;
  final bool isBold;
  final double scale;
  final bool center;
  final bool wrapText;
  final double indent;

  _KotTextRow(
    this.text, {
    this.isBold = false,
    this.scale = 1.0,
    this.center = false,
    this.wrapText = false,
    this.indent = 0,
  });
}

/// Spacing row for vertical gaps
class _KotSpacingRow extends _KotRow {
  final double height;
  _KotSpacingRow(this.height);
}

/// Divider row for horizontal lines
class _KotDividerRow extends _KotRow {
  final String char;
  _KotDividerRow({this.char = '─'});
}

/// Table column definition for proportional layouts
class _KotTableColumn {
  final String text;
  final double width; // Fixed width in pixels (0 means use flex)
  final int flex; // Flex factor for remaining space
  final bool isBold;
  final TextAlign align;
  final double scale; // Relative scale to row scale

  _KotTableColumn(
    this.text, {
    this.width = 0,
    this.flex = 1,
    this.isBold = false,
    this.align = TextAlign.left,
    this.scale = 1.0,
  });
}

/// Table row for multi-column layouts with proportional widths
class _KotTableRow extends _KotRow {
  final List<_KotTableColumn> columns;
  final double scale;

  _KotTableRow(this.columns, {this.scale = 1.0});
}
