import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/build_pagination_control.dart';

void main() {
  Future<void> pumpPagination(
    WidgetTester tester, {
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaginationControl(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: onPageChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the current page and total pages', (tester) async {
    await pumpPagination(
      tester,
      currentPage: 2,
      totalPages: 5,
      onPageChanged: (_) {},
    );

    expect(find.text('Page 2 of 5'), findsOneWidget);
  });

  testWidgets('Previous requests the preceding page', (tester) async {
    int? requestedPage;
    await pumpPagination(
      tester,
      currentPage: 3,
      totalPages: 5,
      onPageChanged: (page) => requestedPage = page,
    );

    await tester.tap(find.text('Previous'));
    await tester.pump();

    expect(requestedPage, 2);
  });

  testWidgets('Next requests the following page', (tester) async {
    int? requestedPage;
    await pumpPagination(
      tester,
      currentPage: 3,
      totalPages: 5,
      onPageChanged: (page) => requestedPage = page,
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(requestedPage, 4);
  });

  testWidgets('Previous does nothing on the first page', (tester) async {
    var callbackCount = 0;
    await pumpPagination(
      tester,
      currentPage: 1,
      totalPages: 5,
      onPageChanged: (_) => callbackCount++,
    );

    await tester.tap(find.text('Previous'));
    await tester.pump();

    expect(callbackCount, 0);
  });

  testWidgets('Next does nothing on the final page', (tester) async {
    var callbackCount = 0;
    await pumpPagination(
      tester,
      currentPage: 5,
      totalPages: 5,
      onPageChanged: (_) => callbackCount++,
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(callbackCount, 0);
  });
}
