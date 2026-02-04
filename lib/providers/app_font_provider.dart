import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global provider for managing font size preferences across the app.
///
/// Font size levels:
/// - 0: Small (default)
/// - 1: Medium
/// - 2: Large
class AppFontProvider extends ChangeNotifier {
  static const String _fontSizeLevelKey = 'app_font_size_level';

  int _fontSizeLevel = 0; // 0 = Small, 1 = Medium, 2 = Large

  int get fontSizeLevel => _fontSizeLevel;

  /// Returns the level name for display (e.g., in tooltips)
  String get fontSizeLevelName {
    switch (_fontSizeLevel) {
      case 0:
        return 'Small';
      case 1:
        return 'Medium';
      case 2:
        return 'Large';
      default:
        return 'Small';
    }
  }

  // ============== Billing Table Semantic Getters ==============

  /// Font size for billing table headers (S:12, M:14, L:16)
  double get billingTableHeaderSize => 12.0 + (_fontSizeLevel * 2);

  /// Font size for billing table item text (S:11, M:13, L:15)
  double get billingTableItemSize => 11.0 + (_fontSizeLevel * 2);

  /// Font size for billing table input fields (S:11, M:13, L:15)
  double get billingTableInputSize => 11.0 + (_fontSizeLevel * 2);

  /// Font size for product card titles (S:14, M:16, L:18)
  double get productCardTitleSize => 14.0 + (_fontSizeLevel * 2);

  // ============== Future Extensibility ==============
  // Add more semantic getters here as needed, e.g.:
  // double get reportTableHeaderSize => 14.0 + (_fontSizeLevel * 2);
  // double get productListItemSize => 12.0 + (_fontSizeLevel * 2);

  AppFontProvider() {
    _loadFontSizeLevel();
  }

  /// Load the saved font size level from SharedPreferences
  Future<void> _loadFontSizeLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontSizeLevel = prefs.getInt(_fontSizeLevelKey) ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading font size level: $e');
    }
  }

  /// Cycle through font size levels: 0 → 1 → 2 → 0
  Future<void> cycleFontSize() async {
    _fontSizeLevel = (_fontSizeLevel + 1) % 3;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_fontSizeLevelKey, _fontSizeLevel);
    } catch (e) {
      debugPrint('Error saving font size level: $e');
    }
  }

  /// Set a specific font size level (0, 1, or 2)
  Future<void> setFontSizeLevel(int level) async {
    if (level < 0 || level > 2) return;

    _fontSizeLevel = level;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_fontSizeLevelKey, _fontSizeLevel);
    } catch (e) {
      debugPrint('Error saving font size level: $e');
    }
  }
}
