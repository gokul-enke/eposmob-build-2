import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/barcode_layout_settings.dart';

void main() {
  group('BarcodeLayoutSettings', () {
    test('fromJson fallbacks match constructor defaults', () {
      // A settings blob missing every key (e.g. written by an older app
      // version) must decode to the same values as a fresh instance —
      // otherwise Reset and "missing key" produce different stickers.
      final fresh = BarcodeLayoutSettings();
      final decoded = BarcodeLayoutSettings.fromJson(const {});

      expect(decoded.stickerSize, fresh.stickerSize);
      expect(decoded.stickersPerRow, fresh.stickersPerRow);
      expect(decoded.pageMargin, fresh.pageMargin);
      expect(decoded.stickerGap, fresh.stickerGap);
      expect(decoded.storeNameFontSize, fresh.storeNameFontSize);
      expect(decoded.productNameFontSize, fresh.productNameFontSize);
      expect(decoded.priceFontSize, fresh.priceFontSize);
      expect(decoded.dateFontSize, fresh.dateFontSize);
      expect(decoded.barcodeNumberFontSize, fresh.barcodeNumberFontSize);
      expect(decoded.barcodeHeight, fresh.barcodeHeight);
      expect(decoded.barcodeWidthPercent, fresh.barcodeWidthPercent);
      expect(decoded.elementSpacing, fresh.elementSpacing);
      expect(decoded.rasterDpi, fresh.rasterDpi);
      expect(decoded.printRotationDegrees, 0);
    });

    test('defaults are one sticker per row with the legacy element gap', () {
      final s = BarcodeLayoutSettings();
      expect(s.stickersPerRow, 1);
      expect(s.barcodeHeight, 15);
      expect(s.elementSpacing, BarcodeLayoutSettings.defaultElementSpacing);
    });

    test('encode/decode round-trips every field', () {
      final original = BarcodeLayoutSettings(
        stickerSize: '40x20mm',
        stickersPerRow: 3,
        pageMargin: 2.5,
        stickerGap: 3.0,
        storeNameFontSize: 12,
        productNameFontSize: 10,
        priceFontSize: 14,
        dateFontSize: 8,
        barcodeNumberFontSize: 7,
        barcodeHeight: 25,
        barcodeWidthPercent: 55,
        elementSpacing: 0.5,
        rasterDpi: 203,
        printRotationDegrees: 270,
      );

      final decoded = BarcodeLayoutSettings.decode(original.encode());

      expect(decoded.toJson(), original.toJson());
    });

    test('sticker dimensions parse for every size in the dropdown list', () {
      const sizes = {
        '50x25mm': (50.0, 25.0),
        '30x20mm': (30.0, 20.0),
        '38x25mm': (38.0, 25.0),
        '40x25mm': (40.0, 25.0),
        '55x35mm': (55.0, 35.0),
        '60x40mm': (60.0, 40.0),
        '70x40mm': (70.0, 40.0),
        '100x50mm': (100.0, 50.0),
        '40x20mm': (40.0, 20.0),
        '91x24mm': (91.0, 24.0),
      };

      for (final entry in sizes.entries) {
        final s = BarcodeLayoutSettings(stickerSize: entry.key);
        expect(s.stickerWidthMm, entry.value.$1, reason: entry.key);
        expect(s.stickerHeightMm, entry.value.$2, reason: entry.key);
      }
    });

    test('unknown sticker size falls back to 50x25mm dimensions', () {
      final s = BarcodeLayoutSettings(stickerSize: 'bogus');
      expect(s.stickerWidthMm, 50);
      expect(s.stickerHeightMm, 25);
    });

    test('fromJson normalizes corrupt or out-of-range saved settings', () {
      final decoded = BarcodeLayoutSettings.fromJson(const {
        'stickerSize': 'bogus',
        'stickersPerRow': 99,
        'pageMargin': -5,
        'stickerGap': 100,
        'barcodeHeight': 200,
        'barcodeWidthPercent': 5,
        'rasterDpi': 1200,
        'printRotationDegrees': 180,
      });

      expect(decoded.stickerSize, '50x25mm');
      expect(decoded.stickersPerRow, 3);
      expect(decoded.pageMargin, 0);
      expect(decoded.stickerGap, 10);
      expect(decoded.barcodeHeight, 60);
      expect(decoded.barcodeWidthPercent, 30);
      expect(decoded.rasterDpi, 300);
      expect(decoded.printRotationDegrees, 0);
    });

    test('print rotation is opt-in and accepts supported corrections', () {
      expect(BarcodeLayoutSettings().printRotationDegrees, 0);
      expect(
        BarcodeLayoutSettings.fromJson(
          const {'printRotationDegrees': 90},
        ).printRotationDegrees,
        90,
      );
      expect(
        BarcodeLayoutSettings.fromJson(
          const {'printRotationDegrees': 270},
        ).printRotationDegrees,
        270,
      );
    });

    test('barcode height supports 5pt while retaining a 15pt default', () {
      expect(BarcodeLayoutSettings().barcodeHeight, 15);
      expect(
        BarcodeLayoutSettings.fromJson(const {'barcodeHeight': 1})
            .barcodeHeight,
        5,
      );
      expect(
        BarcodeLayoutSettings.fromJson(const {'barcodeHeight': 5})
            .barcodeHeight,
        5,
      );
    });
  });
}
