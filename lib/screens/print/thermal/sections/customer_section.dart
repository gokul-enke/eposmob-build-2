import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import '../font_config.dart';
import '../printer_utils.dart';

/// Builds the customer details section of the thermal receipt
/// Includes: Customer name, phone (masked), email, address
class CustomerSectionBuilder {
  final ThermalPrinterUtils printerUtils;

  CustomerSectionBuilder({ThermalPrinterUtils? utils})
      : printerUtils = utils ?? ThermalPrinterUtils();

  List<int> build(
    Generator generator,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    // Add separator line
    bytes += generator.hr();

    // Customer Name + Phone on a single line when both are present
    if ((customerName != null && customerName.isNotEmpty) &&
        (customerPhone != null && customerPhone.isNotEmpty)) {
      final combined = printerUtils.sanitizeText(
          '$customerName - ${StringHelper.maskStringShowLast4(customerPhone)}');
      bytes += generator.text(
        combined,
        styles: PosStyles(
          fontType: fontType,
          height: ThermalFontConfig.textSizeSmall,
          width: ThermalFontConfig.textSizeSmall,
        ),
      );
    } else {
      // Otherwise show whichever exists
      if (customerName != null && customerName.isNotEmpty) {
        bytes += generator.text(
          printerUtils.sanitizeText(customerName),
          styles: PosStyles(
            fontType: fontType,
            height: ThermalFontConfig.textSizeSmall,
            width: ThermalFontConfig.textSizeSmall,
          ),
        );
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        bytes += generator.text(
          printerUtils
              .sanitizeText(StringHelper.maskStringShowLast4(customerPhone)),
          styles: PosStyles(
            fontType: fontType,
            height: ThermalFontConfig.textSizeSmall,
            width: ThermalFontConfig.textSizeSmall,
          ),
        );
      }
    }

    // Customer Address
    if (customerAddress != null && customerAddress.isNotEmpty) {
      bytes += generator.text(
        printerUtils.sanitizeText(customerAddress),
        styles: PosStyles(
          fontType: fontType,
          height: ThermalFontConfig.textSizeSmall,
          width: ThermalFontConfig.textSizeSmall,
        ),
      );
    }

    // Add separator line
    bytes += generator.hr();

    return bytes;
  }
}
