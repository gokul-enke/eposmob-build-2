import 'dart:convert';

/// Holds all user-configurable barcode sticker layout settings.
class BarcodeLayoutSettings {
  static const int currentSchemaVersion = 2;
  static const double defaultBarcodeHeight = 15;

  static const List<String> supportedStickerSizes = [
    '50x25mm',
    '30x20mm',
    '38x25mm',
    '40x25mm',
    '55x35mm',
    '60x40mm',
    '70x40mm',
    '100x50mm',
    '40x20mm',
    '91x24mm',
  ];

  // Sticker dimensions (mm)
  final String stickerSize;

  // Stickers per row
  final int stickersPerRow;

  // Page margin (mm)
  final double pageMargin;

  // Gap between stickers (mm)
  final double stickerGap;

  // Font sizes (pt)
  final double storeNameFontSize;
  final double productNameFontSize;
  final double priceFontSize;
  final double dateFontSize;
  final double barcodeNumberFontSize;

  // Barcode image height (pt)
  final double barcodeHeight;

  // Width occupied by barcode bars as a percentage of the sticker width.
  final double barcodeWidthPercent;

  // Spacing between elements (pt)
  final double elementSpacing;

  // Source raster density used before the printer/driver performs final output.
  final int rasterDpi;

  /// Default gap between sticker elements. 1.5pt reproduces the 2%-of-height
  /// gap the renderer used before this became configurable.
  static const double defaultElementSpacing = 1.5;

  BarcodeLayoutSettings({
    this.stickerSize = '50x25mm',
    this.stickersPerRow = 1,
    this.pageMargin = 0,
    this.stickerGap = 5.0,
    this.storeNameFontSize = 11,
    this.productNameFontSize = 11,
    this.priceFontSize = 13,
    this.dateFontSize = 9,
    this.barcodeNumberFontSize = 9,
    this.barcodeHeight = defaultBarcodeHeight,
    this.barcodeWidthPercent = 70,
    this.elementSpacing = defaultElementSpacing,
    this.rasterDpi = 300,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'stickerSize': stickerSize,
        'stickersPerRow': stickersPerRow,
        'pageMargin': pageMargin,
        'stickerGap': stickerGap,
        'storeNameFontSize': storeNameFontSize,
        'productNameFontSize': productNameFontSize,
        'priceFontSize': priceFontSize,
        'dateFontSize': dateFontSize,
        'barcodeNumberFontSize': barcodeNumberFontSize,
        'barcodeHeight': barcodeHeight,
        'barcodeWidthPercent': barcodeWidthPercent,
        'elementSpacing': elementSpacing,
        'rasterDpi': rasterDpi,
      };

  factory BarcodeLayoutSettings.fromJson(Map<String, dynamic> json) {
    final rawStickerSize = json['stickerSize']?.toString() ?? '50x25mm';
    final rawDpi = (json['rasterDpi'] as num?)?.round() ?? 300;
    return BarcodeLayoutSettings(
      stickerSize: supportedStickerSizes.contains(rawStickerSize)
          ? rawStickerSize
          : '50x25mm',
      stickersPerRow:
          ((json['stickersPerRow'] as num?)?.round() ?? 1).clamp(1, 3).toInt(),
      pageMargin: ((json['pageMargin'] as num?)?.toDouble() ?? 0)
          .clamp(0, 10)
          .toDouble(),
      stickerGap: ((json['stickerGap'] as num?)?.toDouble() ?? 5.0)
          .clamp(0, 10)
          .toDouble(),
      storeNameFontSize: ((json['storeNameFontSize'] as num?)?.toDouble() ?? 11)
          .clamp(4, 24)
          .toDouble(),
      productNameFontSize:
          ((json['productNameFontSize'] as num?)?.toDouble() ?? 11)
              .clamp(4, 24)
              .toDouble(),
      priceFontSize: ((json['priceFontSize'] as num?)?.toDouble() ?? 13)
          .clamp(4, 24)
          .toDouble(),
      dateFontSize: ((json['dateFontSize'] as num?)?.toDouble() ?? 9)
          .clamp(4, 24)
          .toDouble(),
      barcodeNumberFontSize:
          ((json['barcodeNumberFontSize'] as num?)?.toDouble() ?? 9)
              .clamp(4, 24)
              .toDouble(),
      barcodeHeight:
          ((json['barcodeHeight'] as num?)?.toDouble() ?? defaultBarcodeHeight)
              .clamp(5, 60)
              .toDouble(),
      barcodeWidthPercent:
          ((json['barcodeWidthPercent'] as num?)?.toDouble() ?? 70)
              .clamp(30, 95)
              .toDouble(),
      elementSpacing: ((json['elementSpacing'] as num?)?.toDouble() ??
              defaultElementSpacing)
          .clamp(0, 8)
          .toDouble(),
      rasterDpi: rawDpi == 203 ? 203 : 300,
    );
  }

  String encode() => json.encode(toJson());

  static BarcodeLayoutSettings decode(String source) {
    return BarcodeLayoutSettings.fromJson(
        json.decode(source) as Map<String, dynamic>);
  }

  BarcodeLayoutSettings copyWith({
    String? stickerSize,
    int? stickersPerRow,
    double? pageMargin,
    double? stickerGap,
    double? storeNameFontSize,
    double? productNameFontSize,
    double? priceFontSize,
    double? dateFontSize,
    double? barcodeNumberFontSize,
    double? barcodeHeight,
    double? barcodeWidthPercent,
    double? elementSpacing,
    int? rasterDpi,
  }) {
    return BarcodeLayoutSettings(
      stickerSize: stickerSize ?? this.stickerSize,
      stickersPerRow: stickersPerRow ?? this.stickersPerRow,
      pageMargin: pageMargin ?? this.pageMargin,
      stickerGap: stickerGap ?? this.stickerGap,
      storeNameFontSize: storeNameFontSize ?? this.storeNameFontSize,
      productNameFontSize: productNameFontSize ?? this.productNameFontSize,
      priceFontSize: priceFontSize ?? this.priceFontSize,
      dateFontSize: dateFontSize ?? this.dateFontSize,
      barcodeNumberFontSize:
          barcodeNumberFontSize ?? this.barcodeNumberFontSize,
      barcodeHeight: barcodeHeight ?? this.barcodeHeight,
      barcodeWidthPercent: barcodeWidthPercent ?? this.barcodeWidthPercent,
      elementSpacing: elementSpacing ?? this.elementSpacing,
      rasterDpi: rasterDpi ?? this.rasterDpi,
    );
  }

  /// Returns sticker width in mm parsed from stickerSize.
  double get stickerWidthMm {
    switch (stickerSize) {
      case '30x20mm':
        return 30;
      case '40x20mm':
        return 40;
      case '40x25mm':
        return 40;
      case '38x25mm':
        return 38;
      case '55x35mm':
        return 55;
      case '60x40mm':
        return 60;
      case '70x40mm':
        return 70;
      case '100x50mm':
        return 100;
      case '91x24mm':
        return 91;
      default:
        return 50;
    }
  }

  /// Returns sticker height in mm parsed from stickerSize.
  double get stickerHeightMm {
    switch (stickerSize) {
      case '30x20mm':
        return 20;
      case '40x20mm':
        return 20;
      case '40x25mm':
        return 25;
      case '38x25mm':
        return 25;
      case '55x35mm':
        return 35;
      case '60x40mm':
        return 40;
      case '70x40mm':
        return 40;
      case '100x50mm':
        return 50;
      case '91x24mm':
        return 24;
      default:
        return 25;
    }
  }
}
