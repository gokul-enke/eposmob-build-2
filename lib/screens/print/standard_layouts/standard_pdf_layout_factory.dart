import 'package:flutter/foundation.dart';
import 'standard_pdf_layout.dart';
import 'contract_standard_pdf_layout.dart';

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
    'classic': () => const ContractStandardPdfLayout(
          layoutId: 'classic',
          displayName: 'Classic',
        ),
    'simplified_tax_invoice': () => const ContractStandardPdfLayout(
          layoutId: 'simplified_tax_invoice',
          displayName: 'Simplified Tax Invoice',
        ),
    'centered_simplified_tax_invoice': () => const ContractStandardPdfLayout(
          layoutId: 'centered_simplified_tax_invoice',
          displayName: 'Centered Simplified Tax Invoice',
        ),
    'bilingual_centered_tax_invoice': () => const ContractStandardPdfLayout(
          layoutId: 'bilingual_centered_tax_invoice',
          displayName: 'Bilingual Centered Tax Invoice',
        ),
    'boxed_bilingual_tax_invoice': () => const ContractStandardPdfLayout(
          layoutId: 'boxed_bilingual_tax_invoice',
          displayName: 'Boxed Bilingual Tax Invoice',
        ),
    'boxed_header_tax_invoice': () => const ContractStandardPdfLayout(
          layoutId: 'boxed_header_tax_invoice',
          displayName: 'Boxed Header Tax Invoice',
        ),
  };

  /// Get a layout instance based on the theme identifier.
  ///
  /// [activeTheme] - The theme identifier (e.g., "classic", "modern", "minimal")
  ///
  /// Returns the corresponding layout, or the shared Classic contract if the theme
  /// is not found or is null.
  static StandardPdfLayout getLayout(String? activeTheme) {
    final themeKey = activeTheme?.toLowerCase().trim() ?? 'classic';

    if (_layouts.containsKey(themeKey)) {
      debugPrint('[StandardPdfLayoutFactory] Using layout: $themeKey');
      return _layouts[themeKey]!();
    }

    // Fallback to classic for unknown themes
    debugPrint(
        '[StandardPdfLayoutFactory] Unknown theme "$themeKey", falling back to classic');
    return const ContractStandardPdfLayout(
      layoutId: 'classic',
      displayName: 'Classic',
    );
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
