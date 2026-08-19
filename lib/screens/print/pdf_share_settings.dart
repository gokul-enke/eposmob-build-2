import 'package:shared_preferences/shared_preferences.dart';

/// The paper size and visual template used when an invoice PDF is generated
/// for sharing. This is intentionally independent from physical printer
/// settings: thermal printer sizes are never valid share-PDF sizes.
class PdfShareProfile {
  final String paperSize;
  final String theme;

  const PdfShareProfile({
    required this.paperSize,
    required this.theme,
  });
}

class PdfShareSettings {
  PdfShareSettings._();

  static const String paperSizeKey = 'share_pdf_paper_size';
  static const String paperSizeB2BKey = 'share_pdf_paper_size_b2b';
  static const String themeKey = 'share_pdf_receipt_theme';
  static const String themeB2BKey = 'share_pdf_receipt_theme_b2b';

  static const String defaultPaperSize = 'A4';
  static const String defaultTheme = 'classic';
  static const List<String> paperSizes = ['A4', 'A5'];

  static const List<Map<String, String>> themes = [
    {'id': 'classic', 'name': 'Classic'},
    {'id': 'new_classic', 'name': 'New Classic'},
    {'id': 'tax_invoice', 'name': 'Tax Invoice'},
    {'id': 'detailed_tax_invoice', 'name': 'Detailed Tax Invoice'},
    {'id': 'standard_tax_invoice', 'name': 'Standard Tax Invoice'},
    {'id': 'simplified_tax_invoice', 'name': 'Simplified Tax Invoice'},
    {
      'id': 'centered_simplified_tax_invoice',
      'name': 'Centered Simplified Tax Invoice',
    },
    {
      'id': 'bilingual_centered_tax_invoice',
      'name': 'Bilingual Centered Tax Invoice',
    },
    {
      'id': 'boxed_bilingual_tax_invoice',
      'name': 'Boxed Bilingual Tax Invoice',
    },
    {'id': 'boxed_header_tax_invoice', 'name': 'Boxed Header Tax Invoice'},
    {'id': 'corporate_tax_invoice', 'name': 'Corporate Tax Invoice'},
    {'id': 'letterhead_tax_invoice', 'name': 'Letterhead Tax Invoice'},
  ];

  static String paperPreferenceKey({required bool isB2B}) =>
      isB2B ? paperSizeB2BKey : paperSizeKey;

  static String themePreferenceKey({required bool isB2B}) =>
      isB2B ? themeB2BKey : themeKey;

  static bool isSupportedPaperSize(String? value) =>
      value != null && paperSizes.contains(value);

  static bool isSupportedTheme(String? value) =>
      value != null && themes.any((theme) => theme['id'] == value);

  /// Resolves a share profile while retaining compatibility with installations
  /// that only have Billing Printer preferences. Once a dedicated share value
  /// is saved it always wins, so later printer changes cannot alter shared PDFs.
  static PdfShareProfile resolve(
    SharedPreferences preferences, {
    required bool isB2B,
    String? documentTheme,
  }) {
    final paperCandidates = <String?>[
      preferences.getString(paperPreferenceKey(isB2B: isB2B)),
      if (isB2B) preferences.getString(paperSizeKey),
      if (isB2B) preferences.getString('default_paper_size_b2b'),
      preferences.getString('default_paper_size'),
    ];
    final paperSize = paperCandidates.firstWhere(
      isSupportedPaperSize,
      orElse: () => defaultPaperSize,
    )!;

    final themeCandidates = <String?>[
      preferences.getString(themePreferenceKey(isB2B: isB2B)),
      if (isB2B) preferences.getString(themeKey),
      if (isB2B) preferences.getString('billing_receipt_theme_b2b'),
      preferences.getString('billing_receipt_theme'),
      documentTheme,
    ];
    final theme = themeCandidates.firstWhere(
      isSupportedTheme,
      orElse: () => defaultTheme,
    )!;

    return PdfShareProfile(paperSize: paperSize, theme: theme);
  }
}
