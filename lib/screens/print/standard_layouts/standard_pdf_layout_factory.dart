import 'package:flutter/foundation.dart';
import 'standard_pdf_layout.dart';
import 'classic_standard_pdf_layout.dart';
import 'simplified_tax_invoice_standard_pdf_layout.dart';
import 'centered_simplified_tax_invoice_standard_pdf_layout.dart';
import 'bilingual_centered_tax_invoice_standard_pdf_layout.dart';
import 'boxed_bilingual_tax_invoice_standard_pdf_layout.dart';
import 'boxed_header_tax_invoice_standard_pdf_layout.dart';

/// Factory class for creating standard PDF layouts based on theme.
///
/// Usage:
/// ```dart
/// final layout = StandardPdfLayoutFactory.getLayout('classic');
/// await layout.generateAndPrintPdf(params);
/// ```
///
/// If an unknown theme is provided, it falls back to the classic layout.
class StandardPdfLayoutFactory {
  /// Private constructor to prevent instantiation
  StandardPdfLayoutFactory._();

  /// Map of registered layouts
  static final Map<String, StandardPdfLayout Function()> _layouts = {
    'classic': () => ClassicStandardPdfLayout(),
    'simplified_tax_invoice': () => SimplifiedTaxInvoiceStandardPdfLayout(),
    'centered_simplified_tax_invoice': () =>
        CenteredSimplifiedTaxInvoiceStandardPdfLayout(),
    'bilingual_centered_tax_invoice': () =>
        BilingualCenteredTaxInvoiceStandardPdfLayout(),
    'boxed_bilingual_tax_invoice': () =>
        BoxedBilingualTaxInvoiceStandardPdfLayout(),
    'boxed_header_tax_invoice': () => BoxedHeaderTaxInvoiceStandardPdfLayout(),
  };

  /// Get a layout instance based on the theme identifier.
  ///
  /// [activeTheme] - The theme identifier (e.g., "classic", "modern", "minimal")
  ///
  /// Returns the corresponding layout, or Classic if the theme is not found
  /// or is null.
  static StandardPdfLayout getLayout(String? activeTheme) {
    final themeKey = activeTheme?.toLowerCase().trim() ?? 'classic';

    if (_layouts.containsKey(themeKey)) {
      debugPrint('[StandardPdfLayoutFactory] Using layout: $themeKey');
      return _layouts[themeKey]!();
    }

    // Fallback to classic for unknown themes
    debugPrint(
        '[StandardPdfLayoutFactory] Unknown theme "$themeKey", falling back to classic');
    return ClassicStandardPdfLayout();
  }

  /// Register a custom layout.
  ///
  /// This allows for dynamic registration of new themes at runtime.
  ///
  /// [themeId] - Unique identifier for the theme (lowercase)
  /// [layoutFactory] - Factory function that creates the layout instance
  static void registerLayout(
      String themeId, StandardPdfLayout Function() layoutFactory) {
    _layouts[themeId.toLowerCase()] = layoutFactory;
    debugPrint('[StandardPdfLayoutFactory] Registered layout: $themeId');
  }

  /// Get list of all available theme identifiers
  static List<String> get availableThemes => _layouts.keys.toList();

  /// Check if a theme is available
  static bool hasTheme(String themeId) =>
      _layouts.containsKey(themeId.toLowerCase());
}
