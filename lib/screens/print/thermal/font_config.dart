import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Font configuration utilities for thermal printing
/// Provides dynamic font sizing based on paper size (58mm vs 80mm)
class ThermalFontConfig {
  // Font configuration - default fallback (will be overridden by user preference)
  static const PosFontType defaultFontType = PosFontType.fontB;

  // Static text size constants (legacy fallbacks)
  static const PosTextSize textSizeTitle = PosTextSize.size4;
  static const PosTextSize textSizeBig = PosTextSize.size3;
  static const PosTextSize textSizeMedium = PosTextSize.size2;
  static const PosTextSize textSizeSmall = PosTextSize.size1;

  // Dynamic text size helpers based on paper size
  // 58mm paper is narrower, so use smaller sizes
  // 80mm paper has more space, so use larger sizes for hierarchy

  /// Header size (Store Name, Titles) - high importance
  static PosTextSize getHeaderSize(bool is58mm) =>
      is58mm ? PosTextSize.size2 : PosTextSize.size3;

  /// Total/Net Amount size - highest importance
  static PosTextSize getTotalSize(bool is58mm) =>
      is58mm ? PosTextSize.size2 : PosTextSize.size3;

  /// Invoice number, subtitles - medium importance
  static PosTextSize getSubtitleSize(bool is58mm) =>
      is58mm ? PosTextSize.size1 : PosTextSize.size2;

  /// Body text (cart items, details) - normal importance
  static PosTextSize getBodySize(bool is58mm) => PosTextSize.size1;

  /// Footer text (terms, small print) - low importance
  static PosTextSize getSmallSize(bool is58mm) => PosTextSize.size1;
}
