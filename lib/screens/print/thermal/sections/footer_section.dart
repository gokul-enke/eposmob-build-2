import 'package:flutter/material.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/models/document_configurations.dart';
import '../font_config.dart';

/// Builds the footer section of the thermal receipt
/// Includes: Thank you message, Terms & Conditions
class FooterSectionBuilder {
  List<int> buildThankYouMessage(
    Generator generator,
    Map<String, DisplayOption>? displayConfig,
    PosFontType fontType,
  ) {
    List<int> bytes = [];

    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final message = displayConfig?['showThankYouMessage']?.value as String? ??
          'Thank You... Visit Again';
      bytes += generator.text(
          message.isNotEmpty ? message : 'Thank You... Visit Again',
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: ThermalFontConfig.textSizeSmall,
              width: ThermalFontConfig.textSizeSmall));
    }

    return bytes;
  }

  List<int> buildTermsConditions(
    Generator generator,
    Map<String, DisplayOption>? displayConfig,
    DocumentConfig? billDocumentConfig,
    String selectedPaperSize,
    PosFontType fontType,
  ) {
    if (displayConfig?['showTermsConditions']?.visible != true) {
      debugPrint("Terms & Conditions disabled in settings, skipping");
      return [];
    }

    // Get terms from displayConfig value first, then fallback to billDocumentConfig
    String? terms = displayConfig?['showTermsConditions']?.value as String?;
    if (terms == null || terms.trim().isEmpty) {
      terms = billDocumentConfig?.terms;
    }

    if (terms == null || terms.trim().isEmpty) {
      debugPrint("No Terms & Conditions data available from API, skipping");
      return [];
    }

    debugPrint("Generating Terms & Conditions: $terms");

    List<int> bytes = [];

    // Add separator line before terms
    bytes += generator.hr();

    List<String> termsList = terms.split('\n');

    for (var term in termsList) {
      if (term.trim().isNotEmpty) {
        String termText = term.trim();
        int maxCharsPerLine = 48;

        if (termText.length <= maxCharsPerLine) {
          bytes += generator.row([
            PosColumn(
                text: termText,
                width: 12,
                styles: const PosStyles(
                    fontType: PosFontType.fontB,
                    align: PosAlign.left,
                    bold: false,
                    height: ThermalFontConfig.textSizeSmall,
                    width: ThermalFontConfig.textSizeSmall)),
          ]);
        } else {
          // Text wrapping
          String remainingText = termText;

          while (remainingText.isNotEmpty) {
            String currentLine;

            if (remainingText.length <= maxCharsPerLine) {
              currentLine = remainingText;
              remainingText = '';
            } else {
              int breakPoint = maxCharsPerLine;

              for (int i = maxCharsPerLine - 1;
                  i >= maxCharsPerLine - 10 && i >= 0;
                  i--) {
                if (i < remainingText.length && remainingText[i] == ' ') {
                  breakPoint = i;
                  break;
                }
              }

              currentLine = remainingText.substring(0, breakPoint).trim();
              remainingText = remainingText.substring(breakPoint).trim();
            }

            bytes += generator.row([
              PosColumn(
                  text: currentLine,
                  width: 12,
                  styles: const PosStyles(
                      fontType: PosFontType.fontB,
                      align: PosAlign.left,
                      bold: false,
                      height: ThermalFontConfig.textSizeSmall,
                      width: ThermalFontConfig.textSizeSmall)),
            ]);
          }
        }
      }
    }

    // Add separator line after terms
    bytes += generator.hr();
    return bytes;
  }
}
