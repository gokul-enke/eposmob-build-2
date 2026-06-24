import 'dart:math' as math;

/// Pure layout math for the billing sidebar resize behaviour.
///
/// Phase 4 extraction: lifted verbatim out of `billing_page.dart`'s
/// `_getClampedSidebarWidth` so the clamping rules can be unit-tested without
/// mounting the (network-touching) billing page. Behaviour is identical to the
/// original inline implementation.
class BillingSidebarMetrics {
  const BillingSidebarMetrics._();

  /// Preferred minimum sidebar width (collapses below this only when the
  /// usable width is too small to honour it — see [clampedWidth]).
  static const double minWidth = 250;

  /// Hard maximum sidebar width.
  static const double maxWidth = 420;

  /// The main content area is never squeezed below this.
  static const double mainContentMinWidth = 620;

  /// Clamps [desiredWidth] into the sidebar's allowed range for a row of
  /// [usableWidth] logical pixels.
  ///
  /// - The lower bound is [minWidth], but never more than 40% of [usableWidth]
  ///   (so on narrow rows the sidebar can shrink below [minWidth]).
  /// - The upper bound is [maxWidth], but never so wide that the main content
  ///   would drop below [mainContentMinWidth]; and never below the lower bound.
  static double clampedWidth(double usableWidth, double desiredWidth) {
    final double lowerBound = math.min(minWidth, usableWidth * 0.4);
    final double upperBound = math.max(
      lowerBound,
      math.min(
        maxWidth,
        usableWidth - mainContentMinWidth,
      ),
    );
    return desiredWidth.clamp(lowerBound, upperBound).toDouble();
  }
}
