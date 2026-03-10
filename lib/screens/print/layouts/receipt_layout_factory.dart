import 'package:flutter/foundation.dart';
import 'package:pos_machine/screens/print/layouts/arabic_and_english_recipt_layput.dart';
import 'receipt_layout.dart';
import 'classic_receipt_layout.dart';
import 'premium_receipt_layout.dart';
import 'premium1_receipt_layout.dart';
import 'standard_receipt_layout.dart';
import 'supermarket_receipt_layout.dart';

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
    'classic': () => ClassicReceiptLayout(),
    'premium': () => PremiumReceiptLayout(),
    'premium1': () => Premium1ReceiptLayout(),
    'standard': () => StandardReceiptLayout(),
    'arabic_and_english': () => ArabicAndEnglishReceiptLayout(),
    'supermarket': () => SupermarketLayout(),
  };

  /// Get a layout instance based on the theme identifier.
  ///
  /// [activeTheme] - The theme identifier (e.g., "classic", "modern", "minimal")
  ///
  /// Returns the corresponding layout, or [ClassicReceiptLayout] if the theme
  /// is not found or is null.
  static ReceiptLayout getLayout(String? activeTheme) {
    final themeKey = activeTheme?.toLowerCase().trim() ?? 'classic';

    if (_layouts.containsKey(themeKey)) {
      debugPrint('[ReceiptLayoutFactory] Using layout: $themeKey');
      return _layouts[themeKey]!();
    }

    // Fallback to classic for unknown themes
    debugPrint(
        '[ReceiptLayoutFactory] Unknown theme "$themeKey", falling back to classic');
    return ClassicReceiptLayout();
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
