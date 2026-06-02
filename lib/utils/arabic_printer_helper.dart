import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

class ArabicPrinterHelper {
  static const String fontFamily = 'NotoSansArabic';

  /// Renders a list of rows into a single image for thermal printing.
  /// Each row can have multiple columns with specified widths and alignments.
  /// Renders a list of rows into a single image for thermal printing.
  /// Each row can have multiple columns with specified widths and alignments.
  static Future<img.Image> renderReceiptToImage({
    required List<ReceiptRow> rows,
    double width = 580, // Default for 80mm printers
    double fontSize = 24,
    TextDirection textDirection = TextDirection.rtl, // Default to RTL
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.white;

    // First pass: calculate total height
    double currentY = 0;
    for (var row in rows) {
      currentY += row.calculateHeight(width, fontSize, textDirection);
    }

    // Draw background
    canvas.drawRect(Rect.fromLTWH(0, 0, width, currentY), paint);

    // Second pass: render rows
    double drawY = 0;
    for (var row in rows) {
      row.render(canvas, drawY, width, fontSize, textDirection);
      drawY += row.calculateHeight(width, fontSize, textDirection);
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width.toInt(), currentY.toInt());
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null)
      throw Exception("Failed to convert image to byte data");

    return img.decodeImage(byteData.buffer.asUint8List())!;
  }
}

abstract class ReceiptRow {
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection);
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection);
}

class TextRow extends ReceiptRow {
  final String text;
  final TextAlign align;
  final bool isBold;
  final double scale;
  final double verticalPadding;
  final double verticalOffset;
  final TextDirection? textDirectionOverride;

  TextRow(this.text,
      {this.align = TextAlign.center,
      this.isBold = false,
      this.scale = 1.0,
      this.verticalPadding = 6.0,
      this.verticalOffset = 2.0,
      this.textDirectionOverride});

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    final tp =
        _createPainter(width, fontSize, textDirectionOverride ?? textDirection);
    return tp.height + verticalPadding;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final tp =
        _createPainter(width, fontSize, textDirectionOverride ?? textDirection);
    double x = 0;
    if (align == TextAlign.center) {
      x = (width - tp.width) / 2;
    } else if (align == TextAlign.right) {
      x = width - tp.width;
    }
    // For specific alignment with LTR vs RTL
    // If LTR & TextAlign.left, x=0
    // If RTL & TextAlign.right, x = width - tp.width
    // TextPainter handles internal alignment, but offset needs manual calculation if we want precise column placement

    tp.paint(canvas, Offset(x, y + verticalOffset));
  }

  TextPainter _createPainter(
      double width, double fontSize, TextDirection textDirection) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize * scale,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: align,
    )..layout(maxWidth: width);
  }
}

class ReceiptTableRow extends ReceiptRow {
  final List<ReceiptTableColumn> columns;

  ReceiptTableRow(this.columns);

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double maxHeight = 0;
    for (var col in columns) {
      final tp = col.createPainter(width, fontSize, textDirection);
      if (tp.height > maxHeight) maxHeight = tp.height;
    }
    return maxHeight + 10;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    double currentX = 0;

    // For LTR, render 0..N. For RTL, logical list is usually 0..N but displayed Right to Left
    // Actually, ReceiptTableRow defines columns in logical reading order manually usually.
    // In our Arabic demo: [Total, Price, Qty, MRP, Item] -> Displayed Right to Left?
    // Let's assume columns are defined in visual order from Left to Right?
    // Code says: currentX += colWidth. So it renders Left to Right.
    // In Arabic Demo: Col 0 is "Total", Col 4 is "Item".
    // If we render LTR: Total(Left) ... Item(Right).
    // But Arabic wants Item on Right.
    // So distinct lists might be needed OR we just rely on visual order of definition.
    // Since we are refactoring, let's keep it simple: Columns are rendered Left to Right.
    // The Caller defines the order they want.

    for (var col in columns) {
      final colWidth = width * col.weight;
      final tp = col.createPainter(width, fontSize, textDirection);
      final contentWidth =
          (colWidth - (col.horizontalPadding * 2)).clamp(0.0, double.infinity);

      double xOffset = 0;
      if (col.align == TextAlign.center) {
        xOffset = col.horizontalPadding + ((contentWidth - tp.width) / 2);
      } else if (col.align == TextAlign.right) {
        xOffset = col.horizontalPadding + contentWidth - tp.width;
      } else if (col.align == TextAlign.left) {
        xOffset = col.horizontalPadding;
      }

      tp.paint(canvas, Offset(currentX + xOffset, y + 5));
      currentX += colWidth;
    }
  }
}

class ReceiptTableColumn {
  final String text;
  final double weight; // percentage of width (0.0 to 1.0)
  final TextAlign align;
  final bool isBold;
  final double scale; // font scale multiplier (1.0 = normal)
  final int maxLines;
  final bool autoScaleToFit;
  final double minScale;
  final double horizontalPadding;
  final TextDirection? textDirection; // null = inherit from parent context

  ReceiptTableColumn(this.text,
      {required this.weight,
      this.align = TextAlign.right,
      this.isBold = false,
      this.scale = 1.0,
      this.maxLines = 1,
      this.autoScaleToFit = true,
      this.minScale = 0.62,
      this.horizontalPadding = 0,
      this.textDirection});

  TextPainter createPainter(
      double totalWidth, double fontSize, TextDirection contextTextDirection) {
    final double maxWidth = ((totalWidth * weight) - (horizontalPadding * 2))
        .clamp(0.0, double.infinity);
    final double baseFontSize = fontSize * scale;
    final double minFontSize = fontSize * minScale;
    final effectiveTextDirection = textDirection ?? contextTextDirection;

    TextPainter buildPainter(double size, {String? ellipsis}) {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: size,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: ArabicPrinterHelper.fontFamily,
          ),
        ),
        textDirection: effectiveTextDirection,
        textAlign: align,
        maxLines: maxLines,
        ellipsis: ellipsis,
      )..layout(maxWidth: maxWidth);
    }

    if (autoScaleToFit) {
      double currentSize = baseFontSize;
      while (currentSize >= minFontSize) {
        final candidate = buildPainter(currentSize);
        if (candidate.didExceedMaxLines == false) {
          return candidate;
        }
        currentSize -= 1.0;
      }
    }

    return buildPainter(minFontSize, ellipsis: '...');
  }
}

class DividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      10;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y + 5), Offset(width, y + 5), paint);
  }
}

class SpacingRow extends ReceiptRow {
  final double height;

  SpacingRow(this.height);

  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      height;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    // No rendering, just space
  }
}

class QrRow extends ReceiptRow {
  final String data;
  final double size;

  QrRow(this.data, {this.size = 200});

  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      size + 20; // Extra space for quiet zone

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    // Generate QR Code
    // Use fromData for automatic version selection based on data length
    // This prevents QrInputTooLongException for longer data like ZATCA QR codes
    // Use Error Correction Level M for better scannability on thermal printers
    // (Level M provides 15% error correction vs Level L's 7%)
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    // Add quiet zone (white margin) around QR code - 4 modules is standard
    const int quietZoneModules = 4;
    final int totalModules = qrImage.moduleCount + (quietZoneModules * 2);

    // Calculate module size based on total area including quiet zone
    final double moduleSize = size / totalModules;

    // Calculate position to center the entire QR (including quiet zone)
    final double x = (width - size) / 2;
    final double qrStartY = y + 10; // Top padding

    final paint = Paint()..color = Colors.black;

    // Shrink factor to prevent thermal ink bleed (0.85 = 15% gap between modules)
    // This creates small white gaps that prevent ink from bleeding together
    const double shrinkFactor = 0.85;
    final double drawnModuleSize = moduleSize * shrinkFactor;
    final double moduleOffset = (moduleSize - drawnModuleSize) / 2;

    for (int ix = 0; ix < qrImage.moduleCount; ix++) {
      for (int iy = 0; iy < qrImage.moduleCount; iy++) {
        if (qrImage.isDark(iy, ix)) {
          // Offset by quiet zone and apply shrink factor
          final double drawX =
              x + ((ix + quietZoneModules) * moduleSize) + moduleOffset;
          final double drawY =
              qrStartY + ((iy + quietZoneModules) * moduleSize) + moduleOffset;

          canvas.drawRect(
            Rect.fromLTWH(
              drawX,
              drawY,
              drawnModuleSize,
              drawnModuleSize,
            ),
            paint,
          );
        }
      }
    }
  }
}

class ImageRow extends ReceiptRow {
  final ui.Image image;
  final double? width;
  final double? height;
  final TextAlign align;

  ImageRow(this.image,
      {this.width, this.height, this.align = TextAlign.center});

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    if (height != null) return height! + 10;

    // Maintain aspect ratio if width is provided
    if (this.width != null) {
      double ratio = image.height / image.width;
      return (this.width! * ratio) + 10;
    }

    // Scale to fit canvas width if image is wider
    if (image.width > width) {
      double ratio = image.height / image.width;
      return (width * ratio) + 10;
    }

    return image.height.toDouble() + 10;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    double renderWidth = this.width ?? image.width.toDouble();
    double renderHeight = this.height ?? image.height.toDouble();

    if (this.width == null && image.width > width) {
      renderWidth = width;
      renderHeight = width * (image.height / image.width);
    } else if (this.width != null && this.height == null) {
      renderHeight = this.width! * (image.height / image.width);
    }

    double x = 0;
    if (align == TextAlign.center) {
      x = (width - renderWidth) / 2;
    } else if (align == TextAlign.right) {
      x = width - renderWidth;
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y + 5, renderWidth, renderHeight),
      Paint(),
    );
  }
}

/// Row that displays Saudi Riyal symbol alongside an amount
/// The symbol is rendered as an inline image next to the amount text
class SarAmountRow extends ReceiptRow {
  final String label;
  final String amount;
  final ui.Image? sarSymbol;
  final bool isBold;
  final double scale;
  final double symbolSize;

  SarAmountRow({
    required this.label,
    required this.amount,
    this.sarSymbol,
    this.isBold = false,
    this.scale = 1.0,
    this.symbolSize = 20.0,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    final scaledFontSize = fontSize * scale;
    return scaledFontSize + 16; // Add padding
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final scaledFontSize = fontSize * scale;

    // Render label on the right side (for Arabic layout)
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.black,
          fontSize: scaledFontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: TextAlign.right,
    )..layout(maxWidth: width * 0.6);

    // Render amount on the left side
    final amountPainter = TextPainter(
      text: TextSpan(
        text: amount,
        style: TextStyle(
          color: Colors.black,
          fontSize: scaledFontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout(maxWidth: width * 0.3);

    // Position label on right
    final labelX = width - labelPainter.width;
    labelPainter.paint(canvas, Offset(labelX, y + 8));

    // Position SAR symbol and amount on left
    double currentX = 0;

    // Draw SAR symbol if available
    if (sarSymbol != null) {
      final symbolRenderSize = symbolSize * scale;
      final symbolY = y + 8 + (scaledFontSize - symbolRenderSize) / 2;

      canvas.drawImageRect(
        sarSymbol!,
        Rect.fromLTWH(
            0, 0, sarSymbol!.width.toDouble(), sarSymbol!.height.toDouble()),
        Rect.fromLTWH(currentX, symbolY, symbolRenderSize, symbolRenderSize),
        Paint(),
      );
      currentX += symbolRenderSize + 4; // Add small gap after symbol
    }

    // Draw amount
    amountPainter.paint(canvas, Offset(currentX, y + 8));
  }
}
