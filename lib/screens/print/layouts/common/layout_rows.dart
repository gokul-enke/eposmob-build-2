import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

/// Collapses configured bilingual lines into one visual row with exactly one
/// visible space between language runs. Isolates preserve each run's natural
/// direction without adding a visible separator.
String inlineBilingualLabel(String label) {
  final parts = label
      .split(RegExp(r'[\r\n]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length <= 1) return label.trim();

  return parts.map((part) {
    final isArabic = RegExp(r'[؀-ۿ]').hasMatch(part);
    final isolate = isArabic ? '\u2067' : '\u2066';
    return '$isolate$part\u2069';
  }).join(' ');
}

/// Removes punctuation that is redundant when labels and values already have
/// separate receipt columns. Each configured language line is cleaned on its
/// own before it is converted to an inline bilingual label.
String withoutTrailingLabelColons(String label) {
  return label
      .split(RegExp(r'[\r\n]+'))
      .map((part) => part.trim().replaceFirst(RegExp(r':$'), ''))
      .where((part) => part.isNotEmpty)
      .join('\n');
}

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
        final itemFontSize = fontSize * item.scale;
        final contentWidth =
            (width - (padding * 2)).clamp(0.0, double.infinity).toDouble();
        final amountColumnWidth = contentWidth * 0.34;
        final labelColumnWidth = contentWidth * 0.62;
        final currencyMarkSpace = _currencyMarkSpace(item, itemFontSize);
        final valueWidth = (amountColumnWidth - currencyMarkSpace)
            .clamp(0.0, double.infinity)
            .toDouble();
        final valuePainter = _createScaledTextPainter(
          item.value,
          valueWidth,
          itemFontSize,
          item.isBold,
          TextAlign.left,
          TextDirection.ltr,
        );
        final labelPainter = _createScaledTextPainter(
          item.label,
          labelColumnWidth,
          itemFontSize,
          item.isBold,
          TextAlign.right,
          textDirection,
        );
        final contentHeight = valuePainter.height > labelPainter.height
            ? valuePainter.height
            : labelPainter.height;
        h += contentHeight + 8;
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
        final contentWidth =
            (width - (padding * 2)).clamp(0.0, double.infinity).toDouble();
        final amountColumnWidth = contentWidth * 0.34;
        final labelColumnWidth = contentWidth * 0.62;

        double valueOffsetX = padding;
        final currencyMarkSpace = _currencyMarkSpace(item, itemFontSize);
        final valueWidth = (amountColumnWidth - currencyMarkSpace)
            .clamp(0.0, double.infinity)
            .toDouble();
        final valuePainter = _createScaledTextPainter(
          item.value,
          valueWidth,
          itemFontSize,
          item.isBold,
          TextAlign.left,
          TextDirection.ltr,
        );
        final labelPainter = _createScaledTextPainter(
          item.label,
          labelColumnWidth,
          itemFontSize,
          item.isBold,
          TextAlign.right,
          textDirection,
        );
        final contentHeight = valuePainter.height > labelPainter.height
            ? valuePainter.height
            : labelPainter.height;
        final valueY = currentY + ((contentHeight - valuePainter.height) / 2);
        final labelY = currentY + ((contentHeight - labelPainter.height) / 2);

        if (item.icon != null) {
          final double iconSize = itemFontSize * 0.75;
          final src = Rect.fromLTWH(
              0, 0, item.icon!.width.toDouble(), item.icon!.height.toDouble());
          final dst = Rect.fromLTWH(padding,
              currentY + ((contentHeight - iconSize) / 2), iconSize, iconSize);
          canvas.drawImageRect(item.icon!, src, dst, Paint());
          valueOffsetX += iconSize + 4;
        } else if (item.currencySymbol != null &&
            item.currencySymbol!.isNotEmpty) {
          final symbolPainter = TextPainter(
            text: TextSpan(
              text: item.currencySymbol!,
              style: TextStyle(
                color: Colors.black,
                fontSize: itemFontSize,
                fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
                fontFamily: ArabicPrinterHelper.fontFamily,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          symbolPainter.paint(
            canvas,
            Offset(
              valueOffsetX,
              currentY + ((contentHeight - symbolPainter.height) / 2),
            ),
          );
          valueOffsetX += symbolPainter.width + 4;
        }

        valuePainter.paint(canvas, Offset(valueOffsetX, valueY));
        labelPainter.paint(
          canvas,
          Offset(width - padding - labelPainter.width, labelY),
        );

        currentY += contentHeight + 8;
      }
    }
  }

  double _currencyMarkSpace(StandardBoxedLineItem item, double itemFontSize) {
    if (item.icon != null) {
      return (itemFontSize * 0.75) + 4;
    }
    if (item.currencySymbol == null || item.currencySymbol!.isEmpty) {
      return 0;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: item.currencySymbol!,
        style: TextStyle(
          color: Colors.black,
          fontSize: itemFontSize,
          fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: ArabicPrinterHelper.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 4;
  }

  TextPainter _createScaledTextPainter(
    String text,
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
        return painter;
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
    return painter;
  }
}

class StandardBoxedLineItem {
  final String label;
  final String value;
  final bool isBold;
  final double scale;
  final bool isSeparator;
  final ui.Image? icon;
  final String? currencySymbol;

  StandardBoxedLineItem({
    String label = '',
    this.value = '',
    this.isBold = false,
    this.scale = 1.0,
    this.isSeparator = false,
    this.icon,
    this.currencySymbol,
  }) : label = inlineBilingualLabel(label);
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
      final contentWidth =
          (colWidth - (col.horizontalPadding * 2)).clamp(0.0, double.infinity);

      double xOffset = col.horizontalPadding;
      if (col.align == TextAlign.center) {
        xOffset = col.horizontalPadding + ((contentWidth - tp.width) / 2);
      } else if (col.align == TextAlign.right) {
        xOffset = col.horizontalPadding + contentWidth - tp.width;
      } else if (col.align == TextAlign.left) {
        xOffset = col.horizontalPadding;
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
    )..layout(
        maxWidth: ((totalWidth * col.weight) - (col.horizontalPadding * 2))
            .clamp(0.0, double.infinity));
  }
}
