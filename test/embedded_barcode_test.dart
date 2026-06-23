/// Tests for [EmbeddedBarcode] — the pure scale-barcode parser extracted from
/// `billing_page_mobile.dart` (Phase 4). Pins the substring math so the mobile
/// counter's weight/quantity scanning stays correct through refactors.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/embedded_barcode.dart';

void main() {
  // 14-char embedded barcode: '000' + '123456' (product) + '01500' (payload).
  const embeddedWeight = '00012345601500'; // 1.5 kg
  const embeddedPieces = '00012345600003'; // 3 pcs
  const plainEan = '5901234123457'; // 13-char normal EAN

  group('EmbeddedBarcode.isEmbedded', () {
    test('true only for 14-char codes starting with 000', () {
      expect(EmbeddedBarcode.isEmbedded(embeddedWeight), isTrue);
      expect(EmbeddedBarcode.isEmbedded(plainEan), isFalse); // 13 chars
      expect(EmbeddedBarcode.isEmbedded('12345678901234'), isFalse); // no 000
      expect(EmbeddedBarcode.isEmbedded('000123'), isFalse); // too short
      expect(EmbeddedBarcode.isEmbedded(''), isFalse);
    });
  });

  group('EmbeddedBarcode.searchCode', () {
    test('embedded → 6-digit product code (chars 3..9)', () {
      expect(EmbeddedBarcode.searchCode(embeddedWeight), '123456');
      expect(EmbeddedBarcode.searchCode(embeddedPieces), '123456');
    });

    test('non-embedded → full barcode unchanged', () {
      expect(EmbeddedBarcode.searchCode(plainEan), plainEan);
      expect(EmbeddedBarcode.searchCode('42'), '42');
    });
  });

  group('EmbeddedBarcode.weightQuantityKg', () {
    test('decodes KKGGG payload into kilograms', () {
      expect(EmbeddedBarcode.weightQuantityKg(embeddedWeight), 1.5); // 01500
      expect(EmbeddedBarcode.weightQuantityKg('00012345600150'),
          closeTo(0.15, 1e-9)); // 00150 → 0kg + 150g
      expect(EmbeddedBarcode.weightQuantityKg('00012345602000'), 2.0); // 02000
    });
  });

  group('EmbeddedBarcode.pieceQuantity', () {
    test('decodes payload as an integer count', () {
      expect(EmbeddedBarcode.pieceQuantity(embeddedPieces), 3);
      expect(EmbeddedBarcode.pieceQuantity('00012345600025'), 25);
    });
  });
}
