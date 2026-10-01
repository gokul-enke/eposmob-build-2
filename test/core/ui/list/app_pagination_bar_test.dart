import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required int current,
    required int total,
    double width = 800,
    ValueChanged<int>? onPageChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: AppPaginationBar(
                currentPage: current,
                totalPages: total,
                countLabel: '20 on this page',
                onPageChanged: onPageChanged ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('previous and next report neighbouring pages', (tester) async {
    var selected = 0;
    await pumpBar(tester,
        current: 2, total: 3, onPageChanged: (page) => selected = page);

    await tester.tap(find.byTooltip('Previous page'));
    expect(selected, 1);
    await tester.tap(find.byTooltip('Next page'));
    expect(selected, 3);
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.text('20 on this page'), findsOneWidget);
  });

  testWidgets('buttons are disabled at the ends', (tester) async {
    var calls = 0;
    await pumpBar(tester, current: 1, total: 1, onPageChanged: (_) => calls++);

    await tester.tap(find.byTooltip('Previous page'));
    await tester.tap(find.byTooltip('Next page'));
    expect(calls, 0);
  });

  testWidgets('fills its parent with the card radius and a border',
      (tester) async {
    await pumpBar(tester, current: 1, total: 3, width: 360);

    final bar = find.byKey(const ValueKey('app_pagination_bar'));
    expect(tester.getSize(bar).width, 360);
    final decoration =
        tester.widget<Container>(bar).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.card));
    expect(decoration.border, isNotNull);
  });

  testWidgets('stacks the count above the pager when narrow', (tester) async {
    await pumpBar(tester, current: 1, total: 3, width: 360);
    final count = tester.getCenter(find.text('20 on this page'));
    final pager = tester.getCenter(find.text('Page 1 of 3'));
    expect(count.dy, lessThan(pager.dy));

    await pumpBar(tester, current: 1, total: 3, width: 800);
    final wideCount = tester.getCenter(find.text('20 on this page'));
    final widePager = tester.getCenter(find.text('Page 1 of 3'));
    expect(wideCount.dy, closeTo(widePager.dy, 1));
  });

  test('ListPagination numbers rows across pages', () {
    final state = ListPagination(
      currentPage: 3,
      totalPages: 5,
      itemsPerPage: 20,
      onPageChanged: (_) {},
      countLabel: '',
    );
    expect(state.rowNumber(0), 41);
    expect(state.rowNumber(19), 60);
  });

  testWidgets('a long count label never overflows the wide layout',
      (tester) async {
    for (final width in [450.0, 540.0, 600.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: AppPaginationBar(
                currentPage: 12,
                totalPages: 140,
                countLabel: 'Showing 20 customer transactions on this page',
                onPageChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull, reason: 'width ');
    }
  });
}
