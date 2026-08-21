import 'package:flutter/foundation.dart';
import 'receipt_layout.dart';
import 'contract_receipt_layout.dart';
import 'premium_receipt_layout.dart';
import 'premium2_bilingual_receipt_layout.dart';
import 'standard_receipt_layout.dart';

/// Factory class for creating receipt layouts based on theme.
///
/// Usage:
/// ```dart
/// final layout = ReceiptLayoutFactory.getLayout('modern');
/// await layout.printThermal(params);
/// ```
///
/// If an unknown theme is provided, it falls back to the classic layout.
class ReceiptLayoutFactory {
  /// Private constructor to prevent instantiation
  ReceiptLayoutFactory._();

  /// Map of registered layouts
  static final Map<String, ReceiptLayout Function()> _layouts = {
    // The production thermal path for legacy themes is normalized through the
    // shared contract adapter.  Keep the original classes imported and
    // available for reference/custom registration, but do not let their old
    // language/visibility branches bypass the contract.
    'classic': () => ContractReceiptLayout(
          layoutId: 'classic',
          displayName: 'Classic',
        ),
    'premium': () => PremiumReceiptLayout(),
    'premium1': () => ContractReceiptLayout(
          layoutId: 'premium1',
          displayName: 'Premium 1',
        ),
    'premium2': () => ContractReceiptLayout(
          layoutId: 'premium2',
          displayName: 'Premium 2',
        ),
    'premium2_bilingual': () => Premium2BilingualReceiptLayout(),
    'supermarket_en': () => ContractReceiptLayout(
          layoutId: 'supermarket_en',
          displayName: 'Supermarket English',
        ),
    'standard': () => StandardReceiptLayout(),
    'arabic_and_english': () => ContractReceiptLayout(
          layoutId: 'arabic_and_english',
          displayName: 'Arabic & English',
        ),
    'arabic_english_table_headers': () => ContractReceiptLayout(
          layoutId: 'arabic_english_table_headers',
          displayName: 'Arabic & English (Table Headers)',
        ),
    'arabic_and_english_3': () => ContractReceiptLayout(
          layoutId: 'arabic_and_english_3',
          displayName: 'Arabic & English 3',
        ),
    'supermarket': () => ContractReceiptLayout(
          layoutId: 'supermarket',
          displayName: 'Supermarket',
        ),
    'supermarket2': () => ContractReceiptLayout(
          layoutId: 'supermarket2',
          displayName: 'Supermarket 2',
        ),
    'supermarket2_bilingual': () => ContractReceiptLayout(
          layoutId: 'supermarket2_bilingual',
          displayName: 'Supermarket 2 Bilingual',
        ),
    'supermarkerrecpt3': () => ContractReceiptLayout(
          layoutId: 'supermarkerrecpt3',
          displayName: 'Supermarket 3',
        ),
    'bilingual': () => ContractReceiptLayout(
          layoutId: 'bilingual',
          displayName: 'Bilingual',
        ),
    'multi_store': () => ContractReceiptLayout(
          layoutId: 'multi_store',
          displayName: 'Multi Store',
        ),
    'mobile_shop_tax_invoice': () => ContractReceiptLayout(
          layoutId: 'mobile_shop_tax_invoice',
          displayName: 'Mobile Shop Tax Invoice',
        ),
  };

  /// Get a layout instance based on the theme identifier.
  ///
  /// [activeTheme] - The theme identifier (e.g., "classic", "modern", "minimal")
  ///
  /// Returns the corresponding normalized layout, or the normalized classic
  /// adapter if the theme is not found or is null.
  static ReceiptLayout getLayout(String? activeTheme) {
    final themeKey = activeTheme?.toLowerCase().trim() ?? 'classic';

    if (_layouts.containsKey(themeKey)) {
      debugPrint('[ReceiptLayoutFactory] Using layout: $themeKey');
      return _layouts[themeKey]!();
    }

    // Fallback to classic for unknown themes
    debugPrint(
        '[ReceiptLayoutFactory] Unknown theme "$themeKey", falling back to classic');
    return ContractReceiptLayout(
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
      String themeId, ReceiptLayout Function() layoutFactory) {
    _layouts[themeId.toLowerCase()] = layoutFactory;
    debugPrint('[ReceiptLayoutFactory] Registered layout: $themeId');
  }

  /// Get list of all available theme identifiers
  static List<String> get availableThemes => _layouts.keys.toList();

  /// Check if a theme is available
  static bool hasTheme(String themeId) =>
      _layouts.containsKey(themeId.toLowerCase());
}
