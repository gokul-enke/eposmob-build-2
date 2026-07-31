import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/models/barcode_layout_settings.dart';
import 'package:pos_machine/screens/print/barcode_bidi_text.dart';

/// Renders a barcode sticker to a PNG using Flutter's text engine.
///
/// Unlike the `pdf` package — which always lays text out at the font's full
/// metric height (Noto Sans Arabic reserves ~1.85em, leaving big empty bands
/// between lines) — Flutter supports forced struts, giving exact control of
/// each line's height. The resulting PNG is embedded in the PDF page at the
/// sticker's physical size, so the print pipeline stays unchanged.
class BarcodeStickerImageRenderer {
  BarcodeStickerImageRenderer._();

  static double reservedBarcodeHeight(double requestedHeight) => math.max(
        requestedHeight,
        BarcodeLayoutSettings.defaultBarcodeHeight,
      );

  static const String _regularFamily = 'BarcodeStickerNoto';
  static const String _boldFamily = 'BarcodeStickerNotoBold';

  /// PostScript points per millimetre, for converting pt-based settings to px.
  static const double _pointsPerMm = 2.83465;

  static bool _fontsLoaded = false;
  static ui.Image? _sarSymbol;
  static bool _sarLoadAttempted = false;

  static Future<void> _ensureAssets() async {
    if (!_fontsLoaded) {
      final regular = FontLoader(_regularFamily)
        ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
      final bold = FontLoader(_boldFamily)
        ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
      await regular.load();
      await bold.load();
      _fontsLoaded = true;
    }
    if (!_sarLoadAttempted) {
      _sarLoadAttempted = true;
      try {
        final data =
            await rootBundle.load('assets/images/saudi_riyal_symbol.png');
        _sarSymbol = await decodeImageFromList(data.buffer.asUint8List());
      } catch (e) {
        debugPrint('[StickerRenderer] SAR symbol load failed: $e');
      }
    }
  }

  static bool _isRtl(String text) {
    return RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]').hasMatch(text);
  }

  static bool _isDigitsLike(String text) {
    return RegExp(r'^[\d .,:/()\-]+$').hasMatch(text);
  }

  /// Lays out a single line with a forced strut so the line box hugs the
  /// glyph ink instead of the font's oversized default metrics.
  static TextPainter _painter(
    String text, {
    required bool bold,
    double fontSize = 100,
  }) {
    final double strutHeight =
        _isRtl(text) ? 1.15 : (_isDigitsLike(text) ? 0.85 : 1.0);
    final family = bold ? _boldFamily : _regularFamily;
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontSize: fontSize,
          color: const Color(0xFF000000),
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
      textDirection: BarcodeBidiText.directionForText(text),
      maxLines: 1,
      strutStyle: StrutStyle(
        fontFamily: family,
        fontSize: fontSize,
        height: strutHeight,
        forceStrutHeight: true,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    )..layout();
  }

  /// Paints [tp] scaled (BoxFit.contain) and centered inside [slot].
  static void _paintFitted(Canvas canvas, Rect slot, TextPainter tp) {
    if (tp.width <= 0 || tp.height <= 0) return;
    final scale = math.min(slot.width / tp.width, slot.height / tp.height);
    canvas.save();
    canvas.translate(
      slot.center.dx - (tp.width * scale) / 2,
      slot.center.dy - (tp.height * scale) / 2,
    );
    canvas.scale(scale);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  static void _paintBarcode(Canvas canvas, Rect slot, String data) {
    try {
      final elements = pw.Barcode.code128().make(
        data,
        width: slot.width,
        height: slot.height,
        drawText: false,
      );
      final paint = Paint()..color = const Color(0xFF000000);
      for (final e in elements) {
        if (e is pw.BarcodeBar && e.black) {
          canvas.drawRect(
            Rect.fromLTWH(
                slot.left + e.left, slot.top + e.top, e.width, e.height),
            paint,
          );
        }
      }
    } catch (err) {
      debugPrint('[StickerRenderer] Barcode draw failed: $err');
    }
  }

  /// Price line: SAR symbol image (when available) followed by the amount,
  /// scaled together to fit the slot. INR uses the text rupee sign; other
  /// currencies without a symbol image fall back to a text prefix.
  static void _paintPrice(
    Canvas canvas,
    Rect slot, {
    required String priceText,
    required String currency,
  }) {
    final code = currency.trim().toUpperCase();
    ui.Image? symbol;
    String text = priceText;
    if (code == 'INR') {
      text = '₹ $priceText';
    } else if (_sarSymbol != null) {
      symbol = _sarSymbol;
    } else if (code.isNotEmpty) {
      text = '$code $priceText';
    }

    final tp = _painter(text, bold: true);
    if (symbol == null) {
      _paintFitted(canvas, slot, tp);
      return;
    }

    // Digit cap height is ~0.72em at fontSize 100; match the symbol to it.
    const double symbolH = 72.0;
    final double symbolW = symbol.width / symbol.height * symbolH;
    const double gap = 10.0;
    final double totalW = symbolW + gap + tp.width;
    final double totalH = tp.height;

    final scale = math.min(slot.width / totalW, slot.height / totalH);
    canvas.save();
    canvas.translate(
      slot.center.dx - (totalW * scale) / 2,
      slot.center.dy - (totalH * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawImageRect(
      symbol,
      Rect.fromLTWH(0, 0, symbol.width.toDouble(), symbol.height.toDouble()),
      Rect.fromLTWH(0, (totalH - symbolH) / 2, symbolW, symbolH),
      Paint()..filterQuality = FilterQuality.high,
    );
    tp.paint(canvas, Offset(symbolW + gap, 0));
    canvas.restore();
  }

  /// Renders one sticker as PNG bytes. Empty strings hide a line; hidden
  /// lines free their share of the sticker for the remaining content.
  /// Returns null when there is nothing to render.
  static Future<Uint8List?> render({
    required double widthMm,
    required double heightMm,
    String storeName = '',
    String barcodeValue = '',
    bool showBarcodeNumber = true,
    String productName = '',
    String priceText = '',
    String currency = '',
    String dateLine = '',
    required double storeNameFontSize,
    required double productNameFontSize,
    required double priceFontSize,
    required double dateFontSize,
    required double barcodeNumberFontSize,
    required double barcodeHeight,
    double barcodeWidthPercent = 70,
    double elementSpacing = BarcodeLayoutSettings.defaultElementSpacing,
    double pixelsPerMm = 12,
  }) async {
    await _ensureAssets();

    // Each entry has an actual paint weight and a reserved layout weight.
    // Barcode heights below the 15pt default keep the default reservation, so
    // reducing the bars creates whitespace instead of enlarging other fields.
    final entries = <({
      double weight,
      double reservedWeight,
      void Function(Canvas, Rect) paint,
    })>[];

    if (storeName.isNotEmpty) {
      final tp = _painter(storeName, bold: true);
      entries.add((
        weight: storeNameFontSize * 2.0,
        reservedWeight: storeNameFontSize * 2.0,
        paint: (c, r) => _paintFitted(c, r, tp),
      ));
    }

    if (barcodeValue.isNotEmpty) {
      const defaultBarcodeWeight = 35.0;
      const barcodeWeightPerPoint =
          defaultBarcodeWeight / BarcodeLayoutSettings.defaultBarcodeHeight;
      final actualBarcodeWeight = barcodeHeight * barcodeWeightPerPoint;
      final reservedBarcodeWeight =
          reservedBarcodeHeight(barcodeHeight) * barcodeWeightPerPoint;
      entries.add((
        weight: actualBarcodeWeight,
        reservedWeight: reservedBarcodeWeight,
        paint: (c, r) {
          final widthFraction = (barcodeWidthPercent / 100).clamp(0.30, 0.95);
          final inset = r.width * (1 - widthFraction) / 2;
          _paintBarcode(
            c,
            Rect.fromLTRB(r.left + inset, r.top + r.height * 0.05,
                r.right - inset, r.bottom - r.height * 0.05),
            barcodeValue,
          );
        },
      ));

      if (showBarcodeNumber) {
        final tp = _painter(barcodeValue, bold: false);
        entries.add((
          weight: barcodeNumberFontSize * 1.9,
          reservedWeight: barcodeNumberFontSize * 1.9,
          paint: (c, r) => _paintFitted(c, r, tp),
        ));
      }
    }

    if (productName.isNotEmpty) {
      final tp = _painter(productName, bold: false);
      entries.add((
        weight: productNameFontSize * 1.8,
        reservedWeight: productNameFontSize * 1.8,
        paint: (c, r) => _paintFitted(c, r, tp),
      ));
    }

    if (priceText.isNotEmpty) {
      entries.add((
        weight: priceFontSize * 2.3,
        reservedWeight: priceFontSize * 2.3,
        paint: (c, r) =>
            _paintPrice(c, r, priceText: priceText, currency: currency),
      ));
    }

    if (dateLine.isNotEmpty) {
      final tp = _painter(dateLine, bold: true);
      entries.add((
        weight: dateFontSize * 1.8,
        reservedWeight: dateFontSize * 1.8,
        paint: (c, r) => _paintFitted(c, r, tp),
      ));
    }

    if (entries.isEmpty) return null;

    final double totalReservedWeight =
        entries.fold(0, (sum, e) => sum + e.reservedWeight);
    if (totalReservedWeight <= 0) return null;

    final double w = widthMm * pixelsPerMm;
    final double h = heightMm * pixelsPerMm;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final double padX = w * 0.02;
    final double padY = h * 0.035;
    final double gap =
        (elementSpacing / _pointsPerMm * pixelsPerMm).clamp(0.0, h * 0.1);
    final double usableH = h - padY * 2 - gap * (entries.length - 1);

    double y = padY;
    for (final entry in entries) {
      final double reservedSlotH =
          usableH * (entry.reservedWeight / totalReservedWeight);
      final double paintSlotH =
          reservedSlotH * (entry.weight / entry.reservedWeight);
      final double paintY = y + (reservedSlotH - paintSlotH) / 2;
      entry.paint(
        canvas,
        Rect.fromLTWH(padX, paintY, w - padX * 2, paintSlotH),
      );
      y += reservedSlotH + gap;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }
}
