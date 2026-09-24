/// Tests for [EmbeddedBarcode] — the pure scale-barcode parser extracted from
/// `billing_page_mobile.dart` (Phase 4). Pins the substring math so the mobile
/// counter's weight/quantity scanning stays correct through refactors.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/embedded_barcode.dart';

void main() {
  // 12-char embedded barcode: '000' + '0123' (PLU) + '00725' (payload).
  const pluWeight = '000012300725'; // 0.725 kg
  const pluPieces = '000012300003'; // 3 pcs

  // Legacy 14-char layout: '000' + '123456' (product) + '01500' (payload).
  const embeddedWeight = '00012345601500'; // 1.5 kg
  const embeddedPieces = '00012345600003'; // 3 pcs

  const plainEan = '5901234123457'; // 13-char normal EAN

  group('EmbeddedBarcode.isEmbedded', () {
    test('true for 12-char and legacy 14-char codes starting with 000', () {
      expect(EmbeddedBarcode.isEmbedded(pluWeight), isTrue);
      expect(EmbeddedBarcode.isEmbedded(embeddedWeight), isTrue);
    });

    test('false for other lengths, other prefixes and non-digits', () {
      expect(EmbeddedBarcode.isEmbedded(plainEan), isFalse); // 13 chars
      expect(EmbeddedBarcode.isEmbedded('12345678901234'), isFalse); // no 000
      expect(EmbeddedBarcode.isEmbedded('123456789012'), isFalse); // no 000
      expect(EmbeddedBarcode.isEmbedded('000123'), isFalse); // too short
      expect(EmbeddedBarcode.isEmbedded('0001234567890'), isFalse); // 13 chars
      expect(EmbeddedBarcode.isEmbedded('000ABC123456'), isFalse); // letters
      expect(EmbeddedBarcode.isEmbedded(''), isFalse);
    });
  });

  group('EmbeddedBarcode.searchCode', () {
    test('12-char → 4-digit PLU (chars 3..7)', () {
      expect(EmbeddedBarcode.searchCode(pluWeight), '0123');
      expect(EmbeddedBarcode.searchCode(pluPieces), '0123');
    });

    test('legacy 14-char → 6-digit product code (chars 3..9)', () {
      expect(EmbeddedBarcode.searchCode(embeddedWeight), '123456');
      expect(EmbeddedBarcode.searchCode(embeddedPieces), '123456');
    });

    test('non-embedded → full barcode unchanged', () {
      expect(EmbeddedBarcode.searchCode(plainEan), plainEan);
      expect(EmbeddedBarcode.searchCode('42'), '42');
    });
  });

  group('EmbeddedBarcode.weightQuantityKg', () {
    test('decodes the 12-char payload as whole grams', () {
      expect(EmbeddedBarcode.weightQuantityKg(pluWeight),
          closeTo(0.725, 1e-9)); // 00725 → 725 g
      expect(EmbeddedBarcode.weightQuantityKg('000012301500'), 1.5); // 01500
      expect(EmbeddedBarcode.weightQuantityKg('000012302000'), 2.0); // 02000
    });

    test('legacy 14-char payload decodes to the same kilograms', () {
      expect(EmbeddedBarcode.weightQuantityKg(embeddedWeight), 1.5); // 01500
      expect(EmbeddedBarcode.weightQuantityKg('00012345600150'),
          closeTo(0.15, 1e-9)); // 00150 → 150 g
      expect(EmbeddedBarcode.weightQuantityKg('00012345602000'), 2.0); // 02000
    });
  });

  group('EmbeddedBarcode.pieceQuantity', () {
    test('decodes payload as an integer count', () {
      expect(EmbeddedBarcode.pieceQuantity(pluPieces), 3);
      expect(EmbeddedBarcode.pieceQuantity('000012300025'), 25);
      expect(EmbeddedBarcode.pieceQuantity(embeddedPieces), 3);
      expect(EmbeddedBarcode.pieceQuantity('00012345600025'), 25);
    });
  });
}
