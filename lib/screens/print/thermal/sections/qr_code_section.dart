import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pos_machine/models/document_configurations.dart';
import '../font_config.dart';

/// Builds the QR code section of the thermal receipt
class QrCodeSectionBuilder {
  List<int> build(
    Generator generator,
    String qrCodeLinkTemplate,
    String formattedTotal,
    String orderNumber,
    Map<String, DisplayOption>? displayConfig,
    PosFontType fontType,
  ) {
    if (displayConfig?['showQRCode']?.visible != true) {
      debugPrint("QR Code disabled in settings, skipping");
      return [];
    }

    debugPrint("===== QR CODE DEBUG =====");
    debugPrint("Link template: '$qrCodeLinkTemplate'");

    List<int> bytes = [];

    String qrData;

    // Check if the link template is empty or contains placeholders
    if (qrCodeLinkTemplate.isEmpty) {
      debugPrint("WARNING: QR code link template is empty, skipping");
      return [];
    } else if (qrCodeLinkTemplate.contains('{formattedTotal}') ||
        qrCodeLinkTemplate.contains('{orderNumber}')) {
      // Replace placeholders in the template string
      qrData = qrCodeLinkTemplate
          .replaceAll('{formattedTotal}', formattedTotal)
          .replaceAll('{orderNumber}', orderNumber);
    } else {
      // Use the link as-is, or create a UPI payment URL if it looks like a UPI ID
      if (qrCodeLinkTemplate.contains('@')) {
        qrData =
            'upi://pay?pa=$qrCodeLinkTemplate&am=$formattedTotal&tn=$orderNumber&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1';
      } else {
        qrData = qrCodeLinkTemplate;
      }
    }

    try {
      bytes += generator.qrcode(
        qrData,
        size: QRSize.size4,
        align: PosAlign.center,
      );
    } catch (e) {
      debugPrint("ERROR generating QR code: $e");
      return [];
    }

    bytes += generator.emptyLines(1);

    final qrCodeMessage = displayConfig?['showQRCode']?.value as String? ??
        'Scan this QR code to Pay';
    bytes += generator.text(
        qrCodeMessage.isNotEmpty ? qrCodeMessage : 'Scan this QR code to Pay',
        styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            height: ThermalFontConfig.textSizeSmall));
    return bytes;
  }
}
