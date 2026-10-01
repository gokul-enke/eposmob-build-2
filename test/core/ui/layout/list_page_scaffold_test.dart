import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';

void main() {
  final controller = TextEditingController();
  tearDownAll(controller.dispose);

  Widget scaffold({
    bool isLoading = false,
    bool showFilters = true,
    List<String> items = const ['Ann', 'Bob'],
    ValueChanged<int>? onPageChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListPageScaffold<String>(
          header: const PageHeader(icon: Icons.people, title: 'People'),
          filters: FilterPanel(
            title: 'Find',
            resetLabel: 'Reset',
            onSearch: () {},
            onReset: () {},
            fields: [
              TextFilterField(
                controller: controller,
                label: 'Name',
                hint: 'By name',
                icon: Icons.person,
              ),
            ],
          ),
          mobileFilterTexts: const CollapsedFilterTexts(
            title: 'Search and filters',
            collapsedSubtitle: 'Name',
            expandedSubtitle: 'Hide',
          ),
          showFilters: showFilters,
          isLoading: isLoading,
          items: items,
          columns: [
            TableColumnDef(
              label: 'NAME',
              cellBuilder: (item, number) => TableCells.text('$number $item'),
            ),
          ],
          cardBuilder: (item, number) =>
              AppListCard(title: item, subtitle: 'card #$number'),
          emptyState: const Text('No people'),
          pagination: ListPagination(
            currentPage: 2,
            totalPages: 2,
            itemsPerPage: 20,
            onPageChanged: onPageChanged ?? (_) {},
            countLabel: '2 people',
          ),
        ),
      ),
    );
  }

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('wide screens show the filter panel and the table',
      (tester) async {
    await setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(scaffold());

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('21 Ann'), findsOneWidget);
    expect(find.text('2 people'), findsOneWidget);
    expect(find.byType(CollapsibleFilterTile), findsNothing);
  });

  testWidgets('phones collapse the filters and show cards', (tester) async {
    await setSize(tester, const Size(375, 812));
    await tester.pumpWidget(scaffold());

    expect(find.byType(CollapsibleFilterTile), findsOneWidget);
    expect(find.text('Search and filters'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('card #21'), findsOneWidget);
    expect(find.text('NAME'), findsNothing);

    await tester.tap(find.text('Search and filters'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow list area on a wide screen uses cards', (tester) async {
    await setSize(tester, const Size(720, 900));
    await tester.pumpWidget(scaffold());

    expect(find.byType(CollapsibleFilterTile), findsNothing);
    expect(find.text('card #21'), findsOneWidget);
  });

  testWidgets('loading replaces the list but keeps header and filters',
      (tester) async {
    await setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(scaffold(isLoading: true));

    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('2 people'), findsNothing);
  });

  testWidgets('empty lists show the empty state', (tester) async {
    await setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(scaffold(items: const []));
    expect(find.text('No people'), findsOneWidget);
  });

  testWidgets('showFilters: false hides the panel and the phone tile',
      (tester) async {
    await setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(scaffold(showFilters: false));
    expect(find.text('Find'), findsNothing);
    expect(find.text('21 Ann'), findsOneWidget);

    await setSize(tester, const Size(375, 812));
    await tester.pumpWidget(scaffold(showFilters: false));
    expect(find.byType(CollapsibleFilterTile), findsNothing);
    expect(find.text('card #21'), findsOneWidget);
  });
}
