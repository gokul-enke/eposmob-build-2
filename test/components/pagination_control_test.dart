import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/resources/app_translations.dart';

void main() {
  Future<void> pumpPagination(
    WidgetTester tester, {
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations({
          'en': {
            'pagination.previous': 'Previous',
            'pagination.next': 'Next',
            'pagination.page': 'Page',
            'pagination.of': 'of',
          },
          'ar': {
            'pagination.previous': 'السابق',
            'pagination.next': 'التالي',
            'pagination.page': 'صفحة',
            'pagination.of': 'من',
          },
        }),
        locale: locale,
        fallbackLocale: const Locale('en'),
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

  testWidgets('shows Arabic pagination labels', (tester) async {
    await pumpPagination(
      tester,
      currentPage: 2,
      totalPages: 5,
      onPageChanged: (_) {},
      locale: const Locale('ar'),
    );

    expect(find.text('السابق'), findsOneWidget);
    expect(find.text('صفحة 2 من 5'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
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
