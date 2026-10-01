import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Helpers for [PageHeader] actions in screen tests. On narrow headers the
/// actions are folded into the "more" menu, so tests must not assume the
/// button itself is on screen.

bool _isFilterIcon(IconData? icon) =>
    icon == Icons.filter_alt_rounded || icon == Icons.filter_alt_outlined;

/// The filter toggle button when it is shown directly on the header.
Finder headerFilterToggle() => find.byWidgetPredicate(
      (widget) => widget is AppSquareIconButton && _isFilterIcon(widget.icon),
    );

/// Whether the page offers a filter toggle (directly or in the more menu).
bool hasFilterToggle() =>
    headerFilterToggle().evaluate().isNotEmpty ||
    find.byKey(PageHeader.moreActionsKey).evaluate().isNotEmpty;

/// Taps the filter toggle: [key] or the header button when visible,
/// otherwise the matching entry of the more menu.
Future<void> tapFilterToggle(WidgetTester tester, {Key? key}) async {
  final direct = key != null && find.byKey(key).evaluate().isNotEmpty
      ? find.byKey(key)
      : headerFilterToggle();
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct);
    await tester.pump();
    return;
  }
  await tester.tap(find.byKey(PageHeader.moreActionsKey));
  await tester.pumpAndSettle();
  await tester.tap(find
      .descendant(
        of: find.byType(PopupMenuItem<int>),
        matching: find.byWidgetPredicate(
          (widget) => widget is Icon && _isFilterIcon(widget.icon),
        ),
      )
      .last);
  await tester.pumpAndSettle();
}
