import 'package:flutter/material.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:provider/provider.dart';

/// Central policy for deciding when to suppress the OS/system keyboard.
///
/// Keep per-field opt-in by passing `fieldWantsVirtualKeyboardOnly: true`.
/// Control enabled platforms globally via [setSuppressedPlatforms].
class SystemKeyboardPolicy {
  static Set<TargetPlatform> _suppressedPlatforms = <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  };

  static Set<TargetPlatform> get suppressedPlatforms =>
      Set<TargetPlatform>.unmodifiable(_suppressedPlatforms);

  static void setSuppressedPlatforms(Set<TargetPlatform> platforms) {
    _suppressedPlatforms = Set<TargetPlatform>.from(platforms);
  }

  static bool shouldSuppress({
    required bool fieldWantsVirtualKeyboardOnly,
    required bool virtualKeyboardFeatureEnabled,
    required TargetPlatform platform,
  }) {
    if (!fieldWantsVirtualKeyboardOnly || !virtualKeyboardFeatureEnabled) {
      return false;
    }

    return _suppressedPlatforms.contains(platform);
  }

  static bool shouldSuppressForContext({
    required BuildContext context,
    required bool fieldWantsVirtualKeyboardOnly,
  }) {
    final keyboardProvider =
        Provider.of<KeyboardProvider>(context, listen: false);

    return shouldSuppress(
      fieldWantsVirtualKeyboardOnly: fieldWantsVirtualKeyboardOnly,
      virtualKeyboardFeatureEnabled: keyboardProvider.showKeyboardFeature,
      platform: Theme.of(context).platform,
    );
  }
}
