import 'package:flutter/material.dart';
import 'package:pos_machine/core/responsive/breakpoints.dart';

// Re-export the single source of truth so existing
// `import 'package:pos_machine/responsive.dart'` consumers gain access to
// [Breakpoints], [DeviceFormFactor] and the `context.isMobile` extension
// without changing their imports.
export 'package:pos_machine/core/responsive/breakpoints.dart';

/// Picks one of three children based on the available width.
///
/// Thresholds are delegated to [Breakpoints] (the single source of truth);
/// the behaviour is identical to the previous hard-coded 650 / 1100 values.
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;
  final Widget tablet;
  const ResponsiveWidget(
      {super.key,
      required this.mobile,
      required this.desktop,
      required this.tablet});

  static bool isMobile(BuildContext context) =>
      Breakpoints.isMobileWidth(MediaQuery.of(context).size.width);
  static bool isTablet(BuildContext context) =>
      Breakpoints.isTabletWidth(MediaQuery.of(context).size.width);
  static bool isDesktop(BuildContext context) =>
      Breakpoints.isDesktopWidth(MediaQuery.of(context).size.width);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isDesktopWidth(constraints.maxWidth)) {
          return desktop;
        } else if (!Breakpoints.isMobileWidth(constraints.maxWidth)) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}
