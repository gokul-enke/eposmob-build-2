import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import '../font_config.dart';

/// Builds the header section of the thermal receipt
/// Includes: Store name, description, address, FSSAI, telephone, email, invoice title/number
class HeaderSectionBuilder {
  final BuildContext context;

  HeaderSectionBuilder(this.context);

  List<int> build(
      Generator generator,
      Map<String, DisplayOption>? displayConfig,
      DocumentConfig? docConfig,
      String orderDate,
      String orderNumber,
      PosFontType fontType) {
    List<int> bytes = [];

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    // Default to 80mm sizing for header
    const bool is58mm = false;

    // Store Name - HIGH IMPORTANCE (uses larger font)
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = displayConfig?['showStoreName']?.value as String? ??
          docConfig?.header ??
          '';
      if (storeName.isNotEmpty) {
        // Adjust font size based on name length to keep it in one line as requested
        PosTextSize fontSize = ThermalFontConfig.getHeaderSize(is58mm);
        if (storeName.length > 20) {
          fontSize = PosTextSize.size1;
        } else if (storeName.length > 14) {
          fontSize = PosTextSize.size2;
        }

        bytes += generator.row([
          PosColumn(
            text: storeName,
            width: 12,
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.center,
                bold: true,
                width: fontSize,
                height: fontSize),
          ),
        ]);
      }
    }

    // Description (subheader from DocumentConfig or value from displayConfig)
    if (displayConfig?['showDescription']?.visible == true) {
      final description = displayConfig?['showDescription']?.value as String? ??
          docConfig?.subheader ??
          '';
      bytes += generator.row([
        PosColumn(
          text: description.isNotEmpty ? description : '',
          width: 12,
          styles: PosStyles(
            fontType: fontType,
            align: PosAlign.center,
            bold: true,
            height: ThermalFontConfig.getSubtitleSize(is58mm),
            width: ThermalFontConfig.getSubtitleSize(is58mm),
          ),
        ),
      ]);
    }

    // Store Address
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final storeAddress = displayConfig?['showStoreAddress']?.value as String?;
      if (storeAddress != null && storeAddress.isNotEmpty) {
        bytes += generator.row([
          PosColumn(
            text: storeAddress,
            width: 12,
            styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: false,
              height: ThermalFontConfig.textSizeSmall,
            ),
          ),
        ]);
      }
    }

    // FSSAI Info
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        bytes += generator.row([
          PosColumn(
            text: fssaiInfo,
            width: 12,
            styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: false,
              height: ThermalFontConfig.textSizeSmall,
            ),
          ),
        ]);
      }
    }

    // Telephone
    if (displayConfig?['showTel']?.visible == true) {
      final telephone = displayConfig?['showTel']?.value as String? ??
          appSettings?.customerCarePhone ??
          '';
      if (telephone.isNotEmpty) {
        bytes += generator.text('TEL: $telephone',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.center,
                bold: false,
                height: ThermalFontConfig.textSizeSmall));
      }
    }

    // Email
    if (displayConfig?['showEmail']?.visible == true) {
      final email = displayConfig?['showEmail']?.value as String? ??
          appSettings?.customerCareEmail ??
          '';
      if (email.isNotEmpty) {
        bytes += generator.text('Email: $email',
            styles: PosStyles(
                fontType: fontType,
                align: PosAlign.center,
                bold: false,
                height: ThermalFontConfig.textSizeSmall));
      }
    }

    // Invoice Title - MEDIUM IMPORTANCE
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle =
          displayConfig?['showInvoiceTitle']?.value as String? ??
              docConfig?.header ??
              appSettings?.printTitle ??
              '';
      if (invoiceTitle.isNotEmpty) {
        bytes += generator.text(invoiceTitle,
            styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: ThermalFontConfig.getSubtitleSize(is58mm),
              width: ThermalFontConfig.getSubtitleSize(is58mm),
            ));
      }
    }

    // Invoice Number - MEDIUM IMPORTANCE
    if (displayConfig?['showInvoiceNumber']?.visible == true) {
      final invoiceNumberText =
          docConfig?.numberPrefix != null && docConfig!.numberPrefix!.isNotEmpty
              ? '${docConfig.numberPrefix}$orderNumber'
              : '#$orderNumber';

      bytes += generator.text(invoiceNumberText,
          styles: PosStyles(
              fontType: fontType,
              align: PosAlign.center,
              bold: true,
              height: ThermalFontConfig.getSubtitleSize(is58mm),
              width: ThermalFontConfig.getSubtitleSize(is58mm)));

      bytes += generator.emptyLines(1);
    }

    return bytes;
  }
}
