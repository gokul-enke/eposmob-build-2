/// Phase-0 characterization tests for [ResponsiveWidget] — the breakpoint
/// CONTRACT that the responsive refactor is built on.
///
/// Current thresholds (lib/responsive.dart):
///   mobile  : width <  650
///   tablet  : 650 <= width < 1100
///   desktop : width >= 1100
///
/// Both the static predicates (isMobile/isTablet/isDesktop, which read
/// MediaQuery width) and the LayoutBuilder-based child selection (which reads
/// the incoming constraints) are pinned here. When Phase 2 introduces a single
/// `core/responsive` source of truth, these boundaries must stay identical
/// unless the change is intentional.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/responsive.dart';

void main() {
  /// Pumps [child] at a real surface of [width]px so both
  /// `MediaQuery.of(context).size.width` and the `LayoutBuilder` incoming
  /// constraints see the same value. (Sizing only the inner box is not enough:
  /// the default 800px test surface clamps anything wider via loose
  /// constraints, which would make the LayoutBuilder under-report the width.)
  Future<void> pumpAtWidth(
    WidgetTester tester,
    double width,
    Widget child,
  ) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: child,
        ),
      ),
    );
  }

  ResponsiveWidget buildSubject() => const ResponsiveWidget(
        mobile: Text('MOBILE'),
        tablet: Text('TABLET'),
        desktop: Text('DESKTOP'),
      );

  group('ResponsiveWidget — LayoutBuilder child selection', () {
    testWidgets('renders mobile just below the 650 boundary', (tester) async {
      await pumpAtWidth(tester, 649, buildSubject());
      expect(find.text('MOBILE'), findsOneWidget);
      expect(find.text('TABLET'), findsNothing);
      expect(find.text('DESKTOP'), findsNothing);
    });

    testWidgets('renders tablet exactly at 650', (tester) async {
      await pumpAtWidth(tester, 650, buildSubject());
      expect(find.text('TABLET'), findsOneWidget);
    });

    testWidgets('renders tablet just below the 1100 boundary', (tester) async {
      await pumpAtWidth(tester, 1099, buildSubject());
      expect(find.text('TABLET'), findsOneWidget);
    });

    testWidgets('renders desktop exactly at 1100', (tester) async {
      await pumpAtWidth(tester, 1100, buildSubject());
      expect(find.text('DESKTOP'), findsOneWidget);
    });
  });

  group('ResponsiveWidget — static predicates', () {
    Future<({bool mobile, bool tablet, bool desktop})> probe(
      WidgetTester tester,
      double width,
    ) async {
      late bool m, t, d;
      await pumpAtWidth(
        tester,
        width,
        Builder(builder: (context) {
          m = ResponsiveWidget.isMobile(context);
          t = ResponsiveWidget.isTablet(context);
          d = ResponsiveWidget.isDesktop(context);
          return const SizedBox();
        }),
      );
      return (mobile: m, tablet: t, desktop: d);
    }

    testWidgets('isMobile is true below 650 only', (tester) async {
      expect((await probe(tester, 649)).mobile, isTrue);
      expect((await probe(tester, 650)).mobile, isFalse);
    });

    testWidgets('isTablet is true within [650, 1100)', (tester) async {
      expect((await probe(tester, 649)).tablet, isFalse);
      expect((await probe(tester, 650)).tablet, isTrue);
      expect((await probe(tester, 1099)).tablet, isTrue);
      expect((await probe(tester, 1100)).tablet, isFalse);
    });

    testWidgets('isDesktop is true at/above 1100 only', (tester) async {
      expect((await probe(tester, 1099)).desktop, isFalse);
      expect((await probe(tester, 1100)).desktop, isTrue);
    });

    testWidgets('exactly one predicate is true at any width', (tester) async {
      for (final w in [320.0, 649.0, 650.0, 900.0, 1099.0, 1100.0, 1920.0]) {
        final r = await probe(tester, w);
        final trueCount =
            [r.mobile, r.tablet, r.desktop].where((b) => b).length;
        expect(trueCount, 1, reason: 'width=$w should match exactly one band');
      }
    });
  });
}
