import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  const filterKey = ValueKey('filter');
  const exportKey = ValueKey('export');
  const refreshKey = ValueKey('refresh');

  Future<void> pumpHeader(
    WidgetTester tester, {
    required double width,
    VisualDensity density = VisualDensity.standard,
    List<HeaderAction>? actions,
    VoidCallback? onAdd,
    List<Widget> primaryActions = const [],
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(visualDensity: density),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: PageHeader(
                icon: Icons.people,
                title: 'Customers',
                subtitle: 'Manage customers',
                actions: actions ?? const [],
                addLabel: 'Add customer',
                addShortLabel: 'Add',
                onAdd: onAdd,
                primaryActions: primaryActions,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<HeaderAction> threeActions(List<String> log, {bool badge = false}) => [
        HeaderAction.filters(
          key: filterKey,
          showFilters: true,
          showLabel: 'Filters',
          hideLabel: 'Hide filters',
          badge: badge,
          onPressed: () => log.add('filter'),
        ),
        HeaderAction(
          key: exportKey,
          icon: Icons.ios_share,
          label: 'Export',
          onPressed: () => log.add('export'),
        ),
        HeaderAction(
          key: refreshKey,
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: () => log.add('refresh'),
        ),
      ];

  for (final density in [VisualDensity.compact, VisualDensity.standard]) {
    testWidgets('action buttons and Add have the same height ($density)',
        (tester) async {
      await pumpHeader(
        tester,
        width: 1000,
        density: density,
        actions: threeActions([]),
        onAdd: () {},
      );

      final add = tester.getSize(find.byType(FilledButton));
      for (final key in [filterKey, exportKey, refreshKey]) {
        expect(tester.getSize(find.byKey(key)).height, add.height);
      }
      expect(add.height, AppSizes.control);
    });
  }

  testWidgets('wide header shows actions in order before Add', (tester) async {
    final log = <String>[];
    await pumpHeader(tester,
        width: 1000, actions: threeActions(log), onAdd: () => log.add('add'));

    expect(find.text('Manage customers'), findsOneWidget);
    final xs = [filterKey, exportKey, refreshKey]
        .map((key) => tester.getCenter(find.byKey(key)).dx)
        .toList();
    expect(xs, orderedEquals([...xs]..sort()));
    expect(xs.last, lessThan(tester.getCenter(find.byType(FilledButton)).dx));

    await tester.tap(find.byKey(exportKey));
    await tester.tap(find.byKey(refreshKey));
    await tester.tap(find.text('Add customer'));
    expect(log, ['export', 'refresh', 'add']);
    expect(find.byKey(PageHeader.moreActionsKey), findsNothing);
  });

  testWidgets('narrow header folds actions into a menu without overflow',
      (tester) async {
    final log = <String>[];
    await pumpHeader(tester,
        width: 360, actions: threeActions(log, badge: true), onAdd: () {});

    expect(find.byKey(filterKey), findsNothing);
    expect(find.byKey(PageHeader.moreActionsKey), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Manage customers'), findsNothing);
    expect(find.byType(AppBadgeDot), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(PageHeader.moreActionsKey));
    await tester.pumpAndSettle();
    expect(find.text('Hide filters'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(log, ['export']);
  });

  testWidgets('a single action stays visible when narrow', (tester) async {
    await pumpHeader(tester, width: 360, actions: [
      HeaderAction(
        key: refreshKey,
        icon: Icons.refresh,
        label: 'Refresh',
        onPressed: () {},
      ),
    ]);
    expect(find.byKey(refreshKey), findsOneWidget);
    expect(find.byKey(PageHeader.moreActionsKey), findsNothing);
  });

  testWidgets('disabled and busy actions cannot be pressed', (tester) async {
    var presses = 0;
    await pumpHeader(tester, width: 1000, actions: [
      HeaderAction(
        key: exportKey,
        icon: Icons.ios_share,
        label: 'Export',
        busy: true,
        onPressed: () => presses++,
      ),
      const HeaderAction(
        key: refreshKey,
        icon: Icons.refresh,
        label: 'Refresh',
        onPressed: null,
      ),
    ]);
    await tester.tap(find.byKey(exportKey));
    await tester.tap(find.byKey(refreshKey));
    expect(presses, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('without callbacks nothing is shown', (tester) async {
    await pumpHeader(tester, width: 900);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  for (final width in [350.0, 900.0]) {
    testWidgets(
        'workflow labels and disabled controls remain visible at $width',
        (tester) async {
      var closes = 0;
      await pumpHeader(tester,
          width: width,
          actions: threeActions([]),
          primaryActions: [
            const AppOutlinedButton(
                label: 'Open Shift', icon: Icons.lock_open, onPressed: null),
            AppPrimaryButton(
                label: 'Day Close',
                icon: Icons.access_time,
                onPressed: () => closes++),
          ]);
      expect(find.text('Open Shift'), findsOneWidget);
      expect(find.text('Day Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Day Close'));
      expect(closes, 1);
      expect(
          tester
              .widget<AppOutlinedButton>(find.byType(AppOutlinedButton))
              .onPressed,
          isNull);
      final buttonY = tester.getTopLeft(find.byType(AppPrimaryButton)).dy;
      final titleBottom = tester.getBottomLeft(find.text('Customers')).dy;
      expect(buttonY > titleBottom, width < PageHeader.collapseActionsBelow);
    });
  }
}
