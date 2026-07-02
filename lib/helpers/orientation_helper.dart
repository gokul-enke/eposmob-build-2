import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pos_machine/providers/shared_preferences.dart';

/// Screen orientation preference and application logic.
class OrientationHelper {
  OrientationHelper._();

  static const String modeAuto = 'auto';
  static const String modePortrait = 'portrait';
  static const String modeLandscape = 'landscape';

  static const double tabletShortestSideThreshold = 600;

  /// Reads the logical shortest side from the primary view.
  /// Returns 0 when metrics are not ready yet (e.g. cold start).
  static double shortestLogicalSide([FlutterView? view]) {
    view ??= WidgetsBinding.instance.platformDispatcher.views.first;
    final physicalSize = view.physicalSize;
    if (physicalSize.shortestSide <= 0) {
      return 0;
    }
    return physicalSize.shortestSide / view.devicePixelRatio;
  }

  static List<DeviceOrientation> orientationsFor({
    required String mode,
    required double shortestSide,
  }) {
    switch (mode) {
      case modePortrait:
        return const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ];
      case modeLandscape:
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
      default:
        if (shortestSide < tabletShortestSideThreshold) {
          return const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ];
        }
        return const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
    }
  }

  static String labelForMode(String mode) {
    switch (mode) {
      case modePortrait:
        return 'Portrait';
      case modeLandscape:
        return 'Landscape';
      default:
        return 'Auto';
    }
  }

  /// Applies the saved orientation mode, or [modeOverride] when provided.
  /// No-op on web or when display metrics are not ready.
  static Future<void> apply({String? modeOverride}) async {
    if (kIsWeb) return;

    final mode =
        modeOverride ?? await SharedPreferenceProvider().getOrientationMode();
    final shortestSide = shortestLogicalSide();
    if (shortestSide <= 0) return;

    final orientations = orientationsFor(
      mode: mode,
      shortestSide: shortestSide,
    );

    await SystemChrome.setPreferredOrientations(orientations);

    if (kDebugMode) {
      debugPrint(
        'Orientation applied: mode=$mode, shortestSide=$shortestSide, '
        'orientations=$orientations',
      );
    }
  }
}

/// Applies orientation after the first frame and when display metrics change.
class OrientationLock extends StatefulWidget {
  const OrientationLock({super.key, required this.child});

  final Widget child;

  @override
  State<OrientationLock> createState() => _OrientationLockState();
}

class _OrientationLockState extends State<OrientationLock>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyOrientation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _applyOrientation();
  }

  Future<void> _applyOrientation() async {
    await OrientationHelper.apply();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
