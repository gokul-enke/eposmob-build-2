import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import '../font_config.dart';

/// Builds the barcode and date/time section of the thermal receipt
class BarcodeSectionBuilder {
  List<int> buildDateTimeRow(
    Generator generator,
    String orderDate,
    PosFontType fontType,
    bool isFromLocalStorage,
  ) {
    List<int> bytes = [];

    debugPrint("===== BUILD DATE TIME ROW DEBUG =====");
    debugPrint("Order date: $orderDate");
    debugPrint("Is from local storage: $isFromLocalStorage");

    // Use appropriate date formatting based on source
    String formattedDate = isFromLocalStorage
        ? DateHelper.formatToISODateOnlyFromISO(orderDate)
        : DateHelper.formatISODate(orderDate);

    String formattedTime = isFromLocalStorage
        ? DateHelper.formatToISOTimeOnlyFromISO(orderDate)
        : DateHelper.formatISOTimeOnlyToIST(orderDate);

    debugPrint("Formatted date: $formattedDate");
    debugPrint("Formatted time: $formattedTime");

    // Date on left (6 columns), time on right (6 columns)
    bytes += generator.row([
      PosColumn(
          text: formattedDate,
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.left,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall)),
      PosColumn(
          text: formattedTime,
          width: 6,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.right,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall)),
    ]);

    return bytes;
  }

  List<int> buildOrderBarcode(
    Generator generator,
    String orderNumber,
    String selectedPaperSize,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    debugPrint(
        "Generating Order ID barcode: $orderNumber for $selectedPaperSize paper");

    // Adjust barcode size based on paper width
    bool is58mm = selectedPaperSize == '58mm';
    int barcodeHeight = is58mm ? 40 : 30;

    try {
      // Use CODE39 which supports: '0'–'9', A–Z, SP, $, %, *, +, -, ., /
      String cleanOrderNumber =
          orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
      if (cleanOrderNumber.isNotEmpty) {
        List<String> code39Data = cleanOrderNumber.split("");
        bytes += generator.barcode(
          Barcode.code39(code39Data),
          height: barcodeHeight,
          width: 1,
          textPos: BarcodeText.none,
          align: PosAlign.center,
        );
        debugPrint(
            "Generated CODE39 barcode with data: $cleanOrderNumber (height: $barcodeHeight)");
      } else {
        debugPrint("No valid characters for barcode, displaying as text");
      }
    } catch (e) {
      debugPrint(
          "Error generating CODE39 barcode: $e, displaying as text fallback");

      // Final fallback: Just display the order number as text
      bytes += generator.text(orderNumber,
          styles: PosStyles(
              fontType: fontType, align: PosAlign.center, bold: true));
    }

    return bytes;
  }
}
