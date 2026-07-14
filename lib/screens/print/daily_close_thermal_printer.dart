import 'dart:async';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/daily_sales_close.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/screens/print/thermal/printer_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'dart:math' as math;

/// Daily Close Thermal Printer
/// Prints: Daily Sales Close Report
/// Supports responsive layouts for both 80mm and 58mm thermal paper
class DailyCloseThermalPrinter {
  final BuildContext context;
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // =========================================================
  // RESPONSIVE SIZING SYSTEM
  // =========================================================

  /// Print width in pixels for each paper size
  static double getPrintWidth(bool is58mm) => is58mm ? 384.0 : 576.0;

  /// Get base font size based on paper size
  static double getBaseFontSize(bool is58mm) => is58mm ? 22.0 : 24.0;

  /// Get header font scale
  static double getHeaderScale(bool is58mm) => is58mm ? 1.5 : 2.0;

  /// Get title font scale (Section titles)
  static double getTitleScale(bool is58mm) => is58mm ? 1.2 : 1.5;

  /// Get normal text scale
  static double getNormalScale(bool is58mm) => is58mm ? 1.0 : 1.2;

  /// Get small text scale
  static double getSmallScale(bool is58mm) => is58mm ? 0.8 : 1.0;

  /// Get line height multiplier
  static double getLineHeight(bool is58mm) => is58mm ? 1.2 : 1.3;

  /// Get horizontal padding
  static double getPadding(bool is58mm) => is58mm ? 8.0 : 16.0;

  /// Get spacing between sections
  static double getSectionSpacing(bool is58mm) => is58mm ? 10.0 : 16.0;

  /// Get divider font scale
  static double getDividerScale(bool is58mm) => is58mm ? 0.8 : 0.8;

  DailyCloseThermalPrinter(this.context);

  /// Print Daily Close Report
  Future<void> printDailyClose({
    required BluetoothPrinter selectedPrinter,
    required DailySalesCloseData data,
    required String selectedPaperSize,
    required bool includeTransactions,
  }) async {
    debugPrint("===== DAILY CLOSE THERMAL PRINTING ====");
    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: $selectedPaperSize");

    try {
      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully.");

      final bool is58mm = selectedPaperSize == '58mm';
      final double printWidth = getPrintWidth(is58mm);

      // Build receipt rows
      List<_ReportRow> rows = [];

      // ========== HEADER SECTION ==========
      rows.add(_ReportTextRow(
        'DAILY CLOSE REPORT',
        isBold: true,
        scale: getHeaderScale(is58mm),
        center: true,
      ));

      if (data.store?.name != null) {
        rows.add(_ReportTextRow(
          data.store!.name!,
          isBold: true,
          scale: getTitleScale(is58mm),
          center: true,
        ));
      }

      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm)));
      rows.add(_ReportDividerRow(char: '═'));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      // ========== INFO SECTION ==========

      // Opening Date & Time
      if (data.openingDate != null) {
        String openingStr = _formatDateTime(data.openingDate, data.openingTime);
        rows.add(_ReportKeyValueRow(
          'Opening:',
          openingStr,
          scale: getNormalScale(is58mm),
        ));
      }

      // Closing Date & Time
      if (data.closingDate != null) {
        String closingStr = _formatDateTime(data.closingDate, data.closingTime);
        rows.add(_ReportKeyValueRow(
          'Closing:',
          closingStr,
          scale: getNormalScale(is58mm),
        ));
      }

      if (data.salesExecutive?.name != null) {
        rows.add(_ReportKeyValueRow(
          'Executive:',
          data.salesExecutive!.name!,
          scale: getNormalScale(is58mm),
        ));
      }

      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));
      rows.add(_ReportDividerRow(char: '─'));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      // ========== SUMMARY SECTION ==========
      rows.add(_ReportTextRow(
        'SUMMARY',
        isBold: true,
        scale: getTitleScale(is58mm),
        center: true,
      ));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      rows.add(_ReportKeyValueRow(
        'Total Orders:',
        data.totalOrders?.toString() ?? '0',
        scale: getNormalScale(is58mm),
      ));

      rows.add(_ReportKeyValueRow(
        'Total Sales:',
        data.totalSales ?? '0.00',
        isBold: true,
        scale: getTitleScale(is58mm), // Larger for emphasis
      ));

      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));
      rows.add(_ReportDividerRow(char: '─'));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      // ========== PAYMENT BREAKDOWN ==========
      rows.add(_ReportTextRow(
        'PAYMENT BREAKDOWN',
        isBold: true,
        scale: getTitleScale(is58mm),
        center: true,
      ));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      rows.add(_ReportKeyValueRow(
        'Cash Sales:',
        data.totalCash ?? '0.00',
        scale: getNormalScale(is58mm),
      ));

      rows.add(_ReportKeyValueRow(
        'Online Sales:',
        data.totalOnline ?? '0.00',
        scale: getNormalScale(is58mm),
      ));

      rows.add(_ReportKeyValueRow(
        'Credit Amount:',
        data.totalCredit ?? '0.00',
        scale: getNormalScale(is58mm),
      ));

      rows.add(_ReportKeyValueRow(
        'Credit Collected:',
        data.totalCreditCollected ?? '0.00',
        scale: getNormalScale(is58mm),
      ));

      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));
      rows.add(_ReportDividerRow(char: '─'));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      // ========== TOTALS ==========
      rows.add(_ReportKeyValueRow(
        'Payment Received:',
        data.totalPaymentReceived ?? '0.00',
        isBold: true,
        scale: getTitleScale(is58mm),
      ));

      rows.add(_ReportKeyValueRow(
        'Collected on Sale:',
        data.totalAmountCollectedOnSale ?? '0.00',
        scale: getNormalScale(is58mm),
      ));

      // ========== TRANSACTIONS ==========
      if (includeTransactions &&
          data.transactions != null &&
          data.transactions!.isNotEmpty) {
        rows.add(_ReportSpacingRow(getSectionSpacing(is58mm)));
        rows.add(_ReportDividerRow(char: '─'));
        rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

        rows.add(_ReportTextRow(
          'TRANSACTIONS',
          isBold: true,
          scale: getTitleScale(is58mm),
          center: true,
        ));
        rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

        for (int i = 0; i < data.transactions!.length; i++) {
          final tx = data.transactions![i];
          final index = i + 1;

          // Minimal Layout:
          // 1. ORD-xxx ................. 100.00
          //    CASH | Customer Name

          // Row 1: # OrderNo (Left) ... Amount (Right)
          rows.add(_ReportKeyValueRow(
            '$index. ${tx.orderNumber ?? '-'}',
            tx.orderAmount?.toString() ?? '0.00',
            isBold: false,
            scale: getNormalScale(is58mm),
          ));

          // Row 2: Details (Payment Type | Customer | Paid if diff)
          List<String> detailParts = [];
          if (tx.paymentType != null) detailParts.add(tx.paymentType!);
          if (tx.customerName != null &&
              tx.customerName!.isNotEmpty &&
              tx.customerName != 'Default CUSTOMER') {
            detailParts.add(tx.customerName!);
          }
          // Show Paid if different from Order Amount
          if (tx.paidAmount != null &&
              tx.orderAmount != null &&
              tx.paidAmount != tx.orderAmount) {
            detailParts.add('Paid: ${tx.paidAmount}');
          }

          String details = detailParts.join(' | ');

          rows.add(_ReportTextRow(
            '   $details',
            scale: getSmallScale(is58mm),
          ));

          // Minimal spacing between items (no divider)
          if (i < data.transactions!.length - 1) {
            rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.2));
          }
        }
      } else if (includeTransactions && (data.totalOrders ?? 0) > 0) {
        // Show message if orders exist but no details
        rows.add(_ReportSpacingRow(getSectionSpacing(is58mm)));
        rows.add(_ReportDividerRow(char: '─'));
        rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

        rows.add(_ReportTextRow(
          'TRANSACTIONS',
          isBold: true,
          scale: getTitleScale(is58mm),
          center: true,
        ));
        rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

        rows.add(_ReportTextRow(
          '(No transaction details available)',
          scale: getSmallScale(is58mm),
          center: true,
        ));
      }

      // ========== FOOTER ==========
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm)));
      rows.add(_ReportDividerRow(char: '═'));
      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 0.5));

      rows.add(_ReportTextRow(
        'Printed: ${DateHelper.getCurrentFormattedTimeWithAMPM()}',
        scale: getSmallScale(is58mm),
        center: true,
      ));

      rows.add(_ReportSpacingRow(getSectionSpacing(is58mm) * 3)); // Feed space

      // Render and print
      final image = await _renderReportToImage(rows, printWidth, is58mm);
      // ========== DEBUG: SAVE IMAGE TO DESKTOP ==========
      if (kDebugMode) {
        try {
          final String desktopPath = 'C:/Users/gokul/Desktop';
          final String timestamp =
              DateTime.now().millisecondsSinceEpoch.toString();
          final File file = File('$desktopPath/daily_close_${timestamp}.png');
          await file.writeAsBytes(img.encodePng(image));
          debugPrint("Saved debug image to: ${file.path}");
        } catch (e) {
          debugPrint("Error saving debug image: $e");
        }
      }
      // ==================================================
      await _printImage(image, selectedPaperSize, selectedPrinter);

      debugPrint("Daily Close Report printed successfully!");
    } catch (e, stackTrace) {
      debugPrint("ERROR in Daily Close Print: $e");
      debugPrint("Stacktrace: $stackTrace");
      rethrow;
    }
  }

  String _formatDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null) return '';

    try {
      // Parse date (yyyy-MM-dd)
      DateTime date = DateTime.parse(dateStr);

      // If time is provided, combine
      if (timeStr != null) {
        // timeStr is usually HH:mm:ss
        List<String> parts = timeStr.split(':');
        if (parts.length >= 2) {
          date = DateTime(date.year, date.month, date.day, int.parse(parts[0]),
              int.parse(parts[1]), parts.length > 2 ? int.parse(parts[2]) : 0);
        }
      }

      return DateFormat('dd-MM-yyyy hh:mm a').format(date);
    } catch (e) {
      // Fallback
      return '$dateStr ${timeStr ?? ''}'.trim();
    }
  }

  Future<img.Image> _renderReportToImage(
      List<_ReportRow> rows, double width, bool is58mm) async {
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

  double _calculateRowHeight(_ReportRow row, double baseFontSize,
      double lineHeight, double width, double padding, bool is58mm) {
    if (row is _ReportTextRow) {
      final fontSize = baseFontSize * row.scale;
      return fontSize * lineHeight;
    } else if (row is _ReportKeyValueRow) {
      final fontSize = baseFontSize * row.scale;
      final availableWidth = width - (padding * 2);

      // Calculate height for key (max 50% width)
      final keyPainter = TextPainter(
        text: TextSpan(
          text: row.key,
          style: TextStyle(fontSize: fontSize),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      keyPainter.layout(maxWidth: availableWidth / 2);

      // Calculate height for value (max 50% width)
      final valuePainter = TextPainter(
        text: TextSpan(
          text: row.value,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: row.isBold ? FontWeight.bold : FontWeight.normal),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      valuePainter.layout(maxWidth: availableWidth / 2);

      // Return the maximum height of either key or value
      return math.max(keyPainter.height, valuePainter.height) +
          (fontSize * 0.2); // Add a little padding
    } else if (row is _ReportSpacingRow) {
      return row.height;
    } else if (row is _ReportDividerRow) {
      return baseFontSize * getDividerScale(is58mm) * lineHeight;
    }
    return 0;
  }

  double _renderRow(_ReportRow row, Canvas canvas, double yOffset, double width,
      double baseFontSize, double lineHeight, double padding, bool is58mm) {
    if (row is _ReportTextRow) {
      final fontSize = baseFontSize * row.scale;
      final textPainter = TextPainter(
        text: TextSpan(
          text: row.text,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: row.isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: row.center ? TextAlign.center : TextAlign.left,
      );

      final availableWidth = width - (padding * 2);
      textPainter.layout(maxWidth: availableWidth);

      double xOffset = padding;
      if (row.center) {
        xOffset = (width - textPainter.width) / 2;
      }

      textPainter.paint(canvas, Offset(xOffset, yOffset));
      return yOffset + fontSize * lineHeight;
    } else if (row is _ReportKeyValueRow) {
      final fontSize = baseFontSize * row.scale;
      final availableWidth = width - (padding * 2);

      // Key
      final keyPainter = TextPainter(
        text: TextSpan(
          text: row.key,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      keyPainter.layout(maxWidth: availableWidth / 2);

      // Value
      final valuePainter = TextPainter(
        text: TextSpan(
          text: row.value,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: row.isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      valuePainter.layout(maxWidth: availableWidth / 2);

      keyPainter.paint(canvas, Offset(padding, yOffset));
      valuePainter.paint(
          canvas, Offset(width - padding - valuePainter.width, yOffset));

      // Return the actual height used
      return yOffset +
          math.max(keyPainter.height, valuePainter.height) +
          (fontSize * 0.2);
    } else if (row is _ReportSpacingRow) {
      return yOffset + row.height;
    } else if (row is _ReportDividerRow) {
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
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout(maxWidth: width);
      textPainter.paint(canvas, Offset(padding / 2, yOffset));

      return yOffset + dividerFontSize * lineHeight;
    }

    return yOffset;
  }

  Future<void> _printImage(
      img.Image image, String paperSize, BluetoothPrinter printer) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80,
      profile,
    );

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.image(image, align: PosAlign.center);
    bytes += generator.feed(2);
    bytes += generator.cut();

    await _printerUtils.sendPrintJob(printer, bytes);
  }
}

// =========================================================
// ROW TYPES
// =========================================================

abstract class _ReportRow {}

class _ReportTextRow extends _ReportRow {
  final String text;
  final bool isBold;
  final double scale;
  final bool center;

  _ReportTextRow(
    this.text, {
    this.isBold = false,
    this.scale = 1.0,
    this.center = false,
  });
}

class _ReportKeyValueRow extends _ReportRow {
  final String key;
  final String value;
  final bool isBold;
  final double scale;

  _ReportKeyValueRow(
    this.key,
    this.value, {
    this.isBold = false,
    this.scale = 1.0,
  });
}

class _ReportSpacingRow extends _ReportRow {
  final double height;
  _ReportSpacingRow(this.height);
}

class _ReportDividerRow extends _ReportRow {
  final String char;
  _ReportDividerRow({this.char = '─'});
}
