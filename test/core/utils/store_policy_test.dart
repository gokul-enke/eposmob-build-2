import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/utils/store_policy.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('hides external sign-up and subscription links on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(hideExternalCommerceLinks, isTrue);
  });

  test('keeps external links on other platforms', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(hideExternalCommerceLinks, isFalse, reason: platform.name);
    }
  });
}
