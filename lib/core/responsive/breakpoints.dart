import 'package:flutter/widgets.dart';

/// Single source of truth for responsive breakpoints across the app.
///
/// Width bands (logical pixels). These match the historical thresholds that
/// were previously hard-coded in `lib/responsive.dart` and scattered as magic
/// numbers (`< 650`, `>= 1100`) throughout the billing screens:
///
///   mobile  : width <  [mobileMaxWidth]                         (< 650)
///   tablet  : [mobileMaxWidth] <= width < [tabletMaxWidth]      (650 .. <1100)
///   desktop : width >= [tabletMaxWidth]                         (>= 1100)
///
/// New code should prefer the [ResponsiveContext] extension
/// (`context.isMobile` / `context.formFactor`) over re-deriving these.
class Breakpoints {
  const Breakpoints._();

  /// Exclusive upper bound of the mobile band (== tablet lower bound).
  static const double mobileMaxWidth = 650;

  /// Exclusive upper bound of the tablet band (== desktop lower bound).
  static const double tabletMaxWidth = 1100;

  static bool isMobileWidth(double width) => width < mobileMaxWidth;

  static bool isTabletWidth(double width) =>
      width >= mobileMaxWidth && width < tabletMaxWidth;

  static bool isDesktopWidth(double width) => width >= tabletMaxWidth;

  /// Classifies a raw width into a [DeviceFormFactor].
  static DeviceFormFactor formFactorForWidth(double width) {
    if (isMobileWidth(width)) return DeviceFormFactor.mobile;
    if (isTabletWidth(width)) return DeviceFormFactor.tablet;
    return DeviceFormFactor.desktop;
  }
}

/// The three layout bands the app adapts to.
enum DeviceFormFactor { mobile, tablet, desktop }

/// Ergonomic access to the current form factor from a [BuildContext].
///
/// Reads `MediaQuery.of(context).size.width` — i.e. the *screen* width, which
/// is the signal the app uses to choose between phone / tablet / desktop
/// layouts. When you need the width of a specific sub-region instead, use a
/// `LayoutBuilder` and pass `constraints.maxWidth` to the [Breakpoints]
/// helpers directly.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  bool get isMobile => Breakpoints.isMobileWidth(screenWidth);
  bool get isTablet => Breakpoints.isTabletWidth(screenWidth);
  bool get isDesktop => Breakpoints.isDesktopWidth(screenWidth);

  DeviceFormFactor get formFactor =>
      Breakpoints.formFactorForWidth(screenWidth);
}
