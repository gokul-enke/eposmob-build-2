/// Pure parsing for "embedded" weight/quantity barcodes used at the billing
/// counter (EAN-13-style scale labels).
///
/// An embedded barcode here is **14 chars** long and **starts with `000`**:
/// ```
/// 000 | 6-digit product code | 5-digit payload
/// ```
/// The payload encodes either a weight (for KG-priced items) or a piece count.
///
/// Extracted from `billing_page_mobile.dart`'s `processBarcode` (Phase 4) so the
/// fiddly substring math is unit-testable in isolation. Behaviour mirrors the
/// original inline implementation exactly — pure Dart, no Flutter dependency.
class EmbeddedBarcode {
  const EmbeddedBarcode._();

  /// True when [barcode] is a 14-char embedded barcode beginning with `000`.
  static bool isEmbedded(String barcode) =>
      barcode.length == 14 && barcode.startsWith('000');

  /// The code to look products up by: the embedded 6-digit product code when
  /// [barcode] is embedded, otherwise the full [barcode].
  static String searchCode(String barcode) =>
      isEmbedded(barcode) ? barcode.substring(3, 9) : barcode;

  /// The 5-digit payload (positions 9..14) of an embedded barcode.
  static String payload(String barcode) => barcode.substring(9, 14);

  /// Weight in kilograms from a `KKGGG` payload (2-digit kg + 3-digit grams).
  /// e.g. `01500` → 1.5 kg.
  static double weightQuantityKg(String barcode) {
    final p = payload(barcode);
    final kg = double.parse(p.substring(0, 2));
    final grams = double.parse(p.substring(2, 5));
    return kg + grams / 1000;
  }

  /// Piece count from the 5-digit payload. e.g. `00003` → 3.
  static int pieceQuantity(String barcode) => int.parse(payload(barcode));
}
