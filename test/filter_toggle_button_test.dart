import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';

void main() {
  testWidgets('toggles filters and shows the active-filter indicator',
      (tester) async {
    var showFilters = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return FilterToggleButton(
              showFilters: showFilters,
              hasActiveFilters: true,
              onPressed: () {
                setState(() => showFilters = !showFilters);
              },
              showTooltip: 'Show Filters',
              hideTooltip: 'Hide Filters',
            );
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    expect(find.byType(PositionedDirectional), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.byType(PositionedDirectional), findsOneWidget);
  });

  testWidgets('updates the active dot without rebuilding the page',
      (tester) async {
    final controller = TextEditingController();
    var pageBuilds = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageBuilds++;
            return FilterToggleButton(
              showFilters: false,
              hasActiveFilters: false,
              activeFiltersListenable: controller,
              activeFiltersBuilder: () => controller.text.isNotEmpty,
              onPressed: () {},
            );
          },
        ),
      ),
    );

    expect(find.byType(PositionedDirectional), findsNothing);
    expect(pageBuilds, 1);

    controller.text = 'INV-100';
    await tester.pump();

    expect(find.byType(PositionedDirectional), findsOneWidget);
    expect(pageBuilds, 1);
  });

  testWidgets(
      'collapsing filters preserves values and keeps page actions visible',
      (tester) async {
    final controller = TextEditingController(text: 'saved filter');
    var showFilters = true;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Row(
                    children: [
                      FilterToggleButton(
                        showFilters: showFilters,
                        hasActiveFilters: controller.text.isNotEmpty,
                        onPressed: () {
                          setState(() => showFilters = !showFilters);
                        },
                      ),
                      const Text('Create action'),
                    ],
                  ),
                  if (showFilters)
                    TextField(
                      key: const Key('filter-field'),
                      controller: controller,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('filter-field')), findsOneWidget);
    expect(find.text('Create action'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.byKey(const Key('filter-field')), findsNothing);
    expect(find.text('Create action'), findsOneWidget);
    expect(controller.text, 'saved filter');

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(find.byKey(const Key('filter-field')), findsOneWidget);
    expect(find.text('saved filter'), findsOneWidget);
  });
}
