/// Pure parsing for "embedded" weight/quantity barcodes used at the billing
/// counter (EAN-13-style scale labels).
///
/// Two layouts are accepted. Both start with `000` and carry the same 5-digit
/// payload; only the product-code width differs, so the total length tells them
/// apart:
/// ```
/// 12 chars: 000 | 4-digit product code | 5-digit payload   (current)
/// 14 chars: 000 | 6-digit product code | 5-digit payload   (legacy)
/// ```
/// The payload encodes either a weight (for KG-priced items) or a piece count.
///
/// Extracted from `billing_page_mobile.dart`'s `processBarcode` (Phase 4) so the
/// fiddly substring math is unit-testable in isolation. Behaviour mirrors the
/// original inline implementation exactly — pure Dart, no Flutter dependency.
class EmbeddedBarcode {
  const EmbeddedBarcode._();

  /// The `000` marker both layouts begin with.
  static const String _prefix = '000';

  /// Width of the trailing weight/quantity payload, identical in both layouts.
  static const int _payloadLength = 5;

  /// Total lengths that identify an embedded barcode: 12 (4-digit product code)
  /// and the legacy 14 (6-digit product code).
  static const List<int> _acceptedLengths = <int>[12, 14];

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// True when [barcode] is an all-digit 12- or 14-char code beginning `000`.
  static bool isEmbedded(String barcode) =>
      _acceptedLengths.contains(barcode.length) &&
      barcode.startsWith(_prefix) &&
      _digitsOnly.hasMatch(barcode);

  /// The code to look products up by: the embedded product code (4 digits on a
  /// 12-char barcode, 6 on a 14-char one) when [barcode] is embedded, otherwise
  /// the full [barcode].
  static String searchCode(String barcode) => isEmbedded(barcode)
      ? barcode.substring(_prefix.length, barcode.length - _payloadLength)
      : barcode;

  /// The 5-digit payload: always the last five characters of an embedded
  /// barcode, whichever product-code width it uses.
  static String payload(String barcode) =>
      barcode.substring(barcode.length - _payloadLength);

  /// Weight in kilograms from the 5-digit payload, which holds whole grams.
  /// e.g. `01500` → 1.5 kg, `00725` → 0.725 kg.
  static double weightQuantityKg(String barcode) =>
      int.parse(payload(barcode)) / 1000;

  /// Piece count from the 5-digit payload. e.g. `00003` → 3.
  static int pieceQuantity(String barcode) => int.parse(payload(barcode));
}
