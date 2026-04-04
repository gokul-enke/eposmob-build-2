import 'dart:convert';

/// Holds all user-configurable barcode sticker layout settings.
class BarcodeLayoutSettings {
  // Sticker dimensions (mm)
  String stickerSize;

  // Stickers per row
  int stickersPerRow;

  // Page margin (mm)
  double pageMargin;

  // Gap between stickers (mm)
  double stickerGap;

  // Font sizes (pt)
  double storeNameFontSize;
  double productNameFontSize;
  double priceFontSize;
  double dateFontSize;
  double barcodeNumberFontSize;

  // Barcode image height (pt)
  double barcodeHeight;

  // Spacing between elements (pt)
  double elementSpacing;

  BarcodeLayoutSettings({
    this.stickerSize = '50x25mm',
    this.stickersPerRow = 1,
    this.pageMargin = 0,
    this.stickerGap = 5.0,
    this.storeNameFontSize = 9,
    this.productNameFontSize = 9,
    this.priceFontSize = 11,
    this.dateFontSize = 7,
    this.barcodeNumberFontSize = 7,
    this.barcodeHeight = 30,
    this.elementSpacing = 0,
  });

  Map<String, dynamic> toJson() => {
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
        'elementSpacing': elementSpacing,
      };

  factory BarcodeLayoutSettings.fromJson(Map<String, dynamic> json) {
    return BarcodeLayoutSettings(
      stickerSize: json['stickerSize'] as String? ?? '50x25mm',
      stickersPerRow: json['stickersPerRow'] as int? ?? 1,
      pageMargin: (json['pageMargin'] as num?)?.toDouble() ?? 0,
      stickerGap: (json['stickerGap'] as num?)?.toDouble() ?? 5.0,
      storeNameFontSize:
          (json['storeNameFontSize'] as num?)?.toDouble() ?? 9,
      productNameFontSize:
          (json['productNameFontSize'] as num?)?.toDouble() ?? 9,
      priceFontSize: (json['priceFontSize'] as num?)?.toDouble() ?? 11,
      dateFontSize: (json['dateFontSize'] as num?)?.toDouble() ?? 7,
      barcodeNumberFontSize:
          (json['barcodeNumberFontSize'] as num?)?.toDouble() ?? 7,
      barcodeHeight: (json['barcodeHeight'] as num?)?.toDouble() ?? 30,
      elementSpacing: (json['elementSpacing'] as num?)?.toDouble() ?? 0,
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
    double? elementSpacing,
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
      elementSpacing: elementSpacing ?? this.elementSpacing,
    );
  }

  /// Returns sticker width in mm parsed from stickerSize.
  double get stickerWidthMm {
    switch (stickerSize) {
      case '40x20mm':
        return 40;
      case '91x24mm':
        return 91;
      default:
        return 50;
    }
  }

  /// Returns sticker height in mm parsed from stickerSize.
  double get stickerHeightMm {
    switch (stickerSize) {
      case '40x20mm':
        return 20;
      case '91x24mm':
        return 24;
      default:
        return 25;
    }
  }
}
