/// Phase-2 tests for the single breakpoint source of truth
/// (`lib/core/responsive/breakpoints.dart`).
///
/// These pin the same 650 / 1100 contract that `responsive_breakpoints_test.dart`
/// pins for `ResponsiveWidget`, but at the new `Breakpoints` / `ResponsiveContext`
/// API that the rest of the refactor will migrate onto. The two test files must
/// agree — if they ever diverge, the source-of-truth migration broke something.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/responsive/breakpoints.dart';

void main() {
  group('Breakpoints — pure width helpers', () {
    test('mobile band is width < 650', () {
      expect(Breakpoints.isMobileWidth(0), isTrue);
      expect(Breakpoints.isMobileWidth(649), isTrue);
      expect(Breakpoints.isMobileWidth(650), isFalse);
    });

    test('tablet band is [650, 1100)', () {
      expect(Breakpoints.isTabletWidth(649), isFalse);
      expect(Breakpoints.isTabletWidth(650), isTrue);
      expect(Breakpoints.isTabletWidth(1099), isTrue);
      expect(Breakpoints.isTabletWidth(1100), isFalse);
    });

    test('desktop band is width >= 1100', () {
      expect(Breakpoints.isDesktopWidth(1099), isFalse);
      expect(Breakpoints.isDesktopWidth(1100), isTrue);
      expect(Breakpoints.isDesktopWidth(1920), isTrue);
    });

    test('formFactorForWidth classifies each band', () {
      expect(Breakpoints.formFactorForWidth(320), DeviceFormFactor.mobile);
      expect(Breakpoints.formFactorForWidth(800), DeviceFormFactor.tablet);
      expect(Breakpoints.formFactorForWidth(1440), DeviceFormFactor.desktop);
    });

    test('constants match the historical thresholds', () {
      expect(Breakpoints.mobileMaxWidth, 650);
      expect(Breakpoints.tabletMaxWidth, 1100);
    });
  });

  group('ResponsiveContext extension — reads MediaQuery width', () {
    Future<DeviceFormFactor> formFactorAt(
      WidgetTester tester,
      double width,
    ) async {
      late DeviceFormFactor ff;
      late bool mobile, tablet, desktop;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(builder: (context) {
            ff = context.formFactor;
            mobile = context.isMobile;
            tablet = context.isTablet;
            desktop = context.isDesktop;
            return const SizedBox();
          }),
        ),
      );
      // Exactly one predicate must be true and agree with formFactor.
      expect([mobile, tablet, desktop].where((b) => b).length, 1);
      expect(mobile, ff == DeviceFormFactor.mobile);
      expect(tablet, ff == DeviceFormFactor.tablet);
      expect(desktop, ff == DeviceFormFactor.desktop);
      return ff;
    }

    testWidgets('classifies widths at every boundary', (tester) async {
      expect(await formFactorAt(tester, 649), DeviceFormFactor.mobile);
      expect(await formFactorAt(tester, 650), DeviceFormFactor.tablet);
      expect(await formFactorAt(tester, 1099), DeviceFormFactor.tablet);
      expect(await formFactorAt(tester, 1100), DeviceFormFactor.desktop);
    });
  });
}
