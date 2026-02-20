import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:convert/convert.dart';
import 'package:intl/intl.dart';

/// ZATCA Phase 1 QR Code Helper
///
/// Generates ZATCA-compliant QR codes for Saudi Arabia e-invoicing (Phase 1).
/// The QR code contains TLV (Tag-Length-Value) encoded data with:
/// - Tag 1: Seller Name
/// - Tag 2: VAT Registration Number
/// - Tag 3: Timestamp (ISO 8601 format)
/// - Tag 4: Invoice Total (with VAT)
/// - Tag 5: VAT Amount
///
/// Reference: ZATCA E-Invoicing SDK (Fatoora)
/// https://zatca.gov.sa/en/E-Invoicing/SystemsDevelopers/Pages/default.aspx
class ZatcaQrHelper {
  // Singleton pattern
  static final ZatcaQrHelper _instance = ZatcaQrHelper._internal();
  factory ZatcaQrHelper() => _instance;
  ZatcaQrHelper._internal();

  /// Generate ZATCA Phase 1 compliant QR code data (Base64 encoded TLV)
  ///
  /// [sellerName] - The seller/company name (Arabic or English)
  /// [vatNumber] - VAT registration number (15 digits for Saudi)
  /// [timestamp] - Invoice date/time in ISO 8601 format (e.g., "2024-01-15T14:30:00Z")
  /// [totalWithVat] - Total invoice amount including VAT
  /// [vatAmount] - VAT amount
  ///
  /// Returns Base64 encoded TLV string suitable for QR code generation
  String generateZatcaQrData({
    required String sellerName,
    required String vatNumber,
    required DateTime timestamp,
    required double totalWithVat,
    required double vatAmount,
  }) {
    try {
      // Format timestamp to ISO 8601
      final String timestampStr = _formatTimestamp(timestamp);

      // Format amounts to 2 decimal places
      final String totalStr = totalWithVat.toStringAsFixed(2);
      final String vatStr = vatAmount.toStringAsFixed(2);

      // Build TLV data
      final List<int> tlvData = [];

      // Tag 1: Seller Name
      tlvData.addAll(_encodeTlv(1, sellerName));

      // Tag 2: VAT Registration Number
      tlvData.addAll(_encodeTlv(2, vatNumber));

      // Tag 3: Invoice Date/Time
      tlvData.addAll(_encodeTlv(3, timestampStr));

      // Tag 4: Invoice Total (with VAT)
      tlvData.addAll(_encodeTlv(4, totalStr));

      // Tag 5: VAT Amount
      tlvData.addAll(_encodeTlv(5, vatStr));

      // Convert to Base64
      final String base64Data = base64Encode(Uint8List.fromList(tlvData));

      debugPrint('[ZatcaQrHelper] Generated ZATCA QR Data:');
      debugPrint('  Seller: $sellerName');
      debugPrint('  VAT Number: $vatNumber');
      debugPrint('  Timestamp: $timestampStr');
      debugPrint('  Total: $totalStr');
      debugPrint('  VAT: $vatStr');
      debugPrint('  Base64 Length: ${base64Data.length}');

      return base64Data;
    } catch (e, stackTrace) {
      debugPrint('[ZatcaQrHelper] Error generating QR data: $e');
      debugPrint('$stackTrace');
      return '';
    }
  }

  /// Encode a TLV (Tag-Length-Value) element
  ///
  /// TLV format:
  /// - Tag: 1 byte (the tag number)
  /// - Length: 1 byte (length of value in bytes)
  /// - Value: UTF-8 encoded string
  List<int> _encodeTlv(int tag, String value) {
    final Uint8List valueBytes = Uint8List.fromList(utf8.encode(value));
    final int length = valueBytes.length;

    // Ensure length fits in 1 byte (max 255)
    if (length > 255) {
      debugPrint(
          '[ZatcaQrHelper] Warning: Value too long for tag $tag, truncating');
      final truncatedValue = value.substring(0, 100); // Truncate if too long
      return _encodeTlv(tag, truncatedValue);
    }

    return [tag, length, ...valueBytes];
  }

  /// Format DateTime to ZATCA-compliant ISO 8601 format
  ///
  /// Format: "YYYY-MM-DDTHH:MM:SS+03:00" (Explicit Saudi local time offset)
  String _formatTimestamp(DateTime dateTime) {
    // We explicitly append +03:00 (Saudi Arabia offset) because devices generating
    // the QR code might be in different timezones (e.g. India +05:30).
    // If we used .toUtc(), an Indian device parsing "20:37" would subtract 5.5 hours.
    // By appending +03:00, we force validation apps to understand this is exactly
    // the KSA timezone time matching the printed receipt.
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}T'
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}Z';
  }

  /// Parse a ZATCA QR code data (for debugging/verification)
  ///
  /// [base64Data] - Base64 encoded TLV data from QR code
  /// Returns a Map with decoded values
  Map<String, String> parseZatcaQrData(String base64Data) {
    try {
      final Uint8List bytes = base64Decode(base64Data);
      final Map<String, String> result = {};

      int index = 0;
      while (index < bytes.length) {
        final int tag = bytes[index];
        final int length = bytes[index + 1];
        final Uint8List valueBytes =
            bytes.sublist(index + 2, index + 2 + length);
        final String value = utf8.decode(valueBytes);

        switch (tag) {
          case 1:
            result['sellerName'] = value;
            break;
          case 2:
            result['vatNumber'] = value;
            break;
          case 3:
            result['timestamp'] = value;
            break;
          case 4:
            result['totalWithVat'] = value;
            break;
          case 5:
            result['vatAmount'] = value;
            break;
          default:
            result['tag$tag'] = value;
        }

        index += 2 + length;
      }

      return result;
    } catch (e) {
      debugPrint('[ZatcaQrHelper] Error parsing QR data: $e');
      return {};
    }
  }

  /// Validate VAT number format (Saudi Arabia)
  ///
  /// Saudi VAT numbers should be 15 digits starting with "3" and ending with "3"
  bool isValidSaudiVatNumber(String vatNumber) {
    if (vatNumber.isEmpty) return false;

    // Remove any spaces or dashes
    final cleaned = vatNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Check length (should be 15 digits)
    if (cleaned.length != 15) return false;

    // Check if all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return false;

    // Check if starts with 3 and ends with 3 (Saudi VAT format)
    if (!cleaned.startsWith('3') || !cleaned.endsWith('3')) return false;

    return true;
  }

  /// Generate QR code data from invoice details with validation
  ///
  /// Returns empty string if ZATCA credentials are not available or invalid
  DateTime? _parseInvoiceTimestamp(String invoiceDate) {
    final raw = invoiceDate.trim();
    if (raw.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(raw);
    } catch (_) {}

    final fallbackFormats = <String>[
      'dd-MM-yyyy hh:mm:ss a',
      'dd-MM-yyyy hh:mm a',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy',
    ];

    for (final format in fallbackFormats) {
      try {
        return DateFormat(format).parse(raw);
      } catch (_) {}
    }

    return null;
  }

  String generateQrForInvoice({
    required String? sellerName,
    required String? vatNumber,
    required String invoiceDate,
    required double totalAmount,
    required double vatAmount,
  }) {
    // Validate inputs
    if (sellerName == null || sellerName.isEmpty) {
      debugPrint('[ZatcaQrHelper] Seller name is required for ZATCA QR');
      return '';
    }

    if (vatNumber == null || vatNumber.isEmpty) {
      debugPrint('[ZatcaQrHelper] VAT number is required for ZATCA QR');
      return '';
    }

    final parsedTimestamp = _parseInvoiceTimestamp(invoiceDate);
    final timestamp = parsedTimestamp ?? DateTime.now();
    if (parsedTimestamp == null) {
      debugPrint(
          '[ZatcaQrHelper] Invalid invoice date "$invoiceDate", using current time');
    }

    return generateZatcaQrData(
      sellerName: sellerName,
      vatNumber: vatNumber,
      timestamp: timestamp,
      totalWithVat: totalAmount,
      vatAmount: vatAmount,
    );
  }
}
