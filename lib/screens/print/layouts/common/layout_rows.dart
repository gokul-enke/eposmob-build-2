import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

class StandardThinDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      6;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, y + 3),
      Offset(width, y + 3),
      paint,
    );
  }
}

class StandardDottedDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      6;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 2;

    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    double currentX = 0;

    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, y + 3),
        Offset(currentX + dashWidth, y + 3),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }
}

class StandardBoxedTotalsRow extends ReceiptRow {
  final List<StandardBoxedLineItem> items;
  final double cornerRadius;
  final double padding;

  StandardBoxedTotalsRow({
    required this.items,
    this.cornerRadius = 12.0,
    this.padding = 15.0,
  });

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double h = padding * 2;
    for (var item in items) {
      if (item.isSeparator) {
        h += 12;
      } else {
        h += (fontSize * item.scale) + 8;
      }
    }
    return h;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          1, y, width - 2, calculateHeight(width, fontSize, textDirection) - 2),
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(rect, paint);

    double currentY = y + padding;

    for (var item in items) {
      if (item.isSeparator) {
        final sepPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 2;

        const double dashWidth = 4.0;
        const double dashSpace = 3.0;
        double currentX = padding;
        final double endX = width - padding;

        while (currentX < endX) {
          canvas.drawLine(
            Offset(currentX, currentY + 6),
            Offset(currentX + dashWidth, currentY + 6),
            sepPaint,
          );
          currentX += dashWidth + dashSpace;
        }
        currentY += 12;
      } else {
        final itemFontSize = fontSize * item.scale;

        double valueOffsetX = padding;
        if (item.icon != null) {
          final double iconSize = itemFontSize * 0.75;
          final src = Rect.fromLTWH(
              0, 0, item.icon!.width.toDouble(), item.icon!.height.toDouble());
          final dst = Rect.fromLTWH(
              padding, currentY + (itemFontSize - iconSize) / 2 + (itemFontSize * 0.08), iconSize, iconSize);
          canvas.drawImageRect(item.icon!, src, dst, Paint());
          valueOffsetX += iconSize + 4;
        }

        _drawScaledText(
          canvas,
          item.value,
          Offset(valueOffsetX, currentY),
          (width * 0.50) - (valueOffsetX - padding),
          itemFontSize,
          item.isBold,
          TextAlign.left,
          TextDirection.ltr,
        );

        _drawScaledText(
          canvas,
          item.label,
          Offset(width - padding, currentY),
          width * 0.70,
          itemFontSize,
          item.isBold,
          TextAlign.right,
          textDirection,
        );

        currentY += itemFontSize + 8;
      }
    }
  }

  void _drawScaledText(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth,
    double fontSize,
    bool isBold,
    TextAlign align,
    TextDirection textDirection,
  ) {
    double currentFontSize = fontSize;
    const double minFontSize = 8.0;

    while (currentFontSize >= minFontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: currentFontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: ArabicPrinterHelper.fontFamily,
          ),
        ),
        textDirection: textDirection,
        textAlign: align,
      )..layout();

      if (painter.width <= maxWidth) {
        double x = offset.dx;
        if (align == TextAlign.right) {
          x -= painter.width;
        }
        painter.paint(canvas, Offset(x, offset.dy));
        return;
      }

      currentFontSize -= 1.0;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: minFontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);

    double x = offset.dx;
    if (align == TextAlign.right) {
      x -= painter.width;
    }
    painter.paint(canvas, Offset(x, offset.dy));
  }
}

class StandardBoxedLineItem {
  final String label;
  final String value;
  final bool isBold;
  final double scale;
  final bool isSeparator;
  final ui.Image? icon;

  StandardBoxedLineItem({
    this.label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
    this.icon,
  });
}

class MultiLineReceiptTableRow extends ReceiptRow {
  final List<ReceiptTableColumn> columns;
  final int? maxLines;

  MultiLineReceiptTableRow(this.columns, {this.maxLines = 2});

  @override
  double calculateHeight(
      double width, double fontSize, TextDirection textDirection) {
    double maxHeight = 0;
    for (var col in columns) {
      final tp = _createPainter(col, width, fontSize, textDirection);
      if (tp.height > maxHeight) maxHeight = tp.height;
    }
    return maxHeight + 4;
  }

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    double currentX = 0;

    for (var col in columns) {
      final colWidth = width * col.weight;
      final tp = _createPainter(col, width, fontSize, textDirection);

      double xOffset = 0;
      if (col.align == TextAlign.center) {
        xOffset = (colWidth - tp.width) / 2;
      } else if (col.align == TextAlign.right) {
        xOffset = colWidth - tp.width;
      } else if (col.align == TextAlign.left) {
        xOffset = 0;
      }

      tp.paint(canvas, Offset(currentX + xOffset, y + 2));
      currentX += colWidth;
    }
  }

  TextPainter _createPainter(ReceiptTableColumn col, double totalWidth,
      double fontSize, TextDirection textDirection) {
    return TextPainter(
      text: TextSpan(
        text: col.text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize * col.scale,
          fontWeight: col.isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: col.align,
      maxLines: maxLines,
    )..layout(maxWidth: totalWidth * col.weight);
  }
}
