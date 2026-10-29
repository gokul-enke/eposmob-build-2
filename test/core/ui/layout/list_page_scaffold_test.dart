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
    double? minTableWidth,
    ScrollController? tableScrollController,
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
          minTableWidth: minTableWidth,
          tableScrollController: tableScrollController,
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

  // Big monitors: the page fills the area up to 1920 wide, then centres.
  testWidgets('big screens fill the width up to the content limit',
      (tester) async {
    await setSize(tester, const Size(1800, 900));
    await tester.pumpWidget(scaffold());
    expect(tester.getSize(find.byType(PageHeader)).width,
        1800 - 2 * AppSpacing.xl);
    expect(tester.getTopLeft(find.byType(PageHeader)).dx, AppSpacing.xl);
  });

  testWidgets('wider than the limit the page stays centred at the limit',
      (tester) async {
    await setSize(tester, const Size(2600, 900));
    await tester.pumpWidget(scaffold());
    expect(tester.getSize(find.byType(PageHeader)).width,
        ListLayoutBreakpoints.maxContentWidth);
    expect(tester.getTopLeft(find.byType(PageHeader)).dx,
        (2600 - ListLayoutBreakpoints.maxContentWidth) / 2);
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

  // The table card fills the page height, so big screens show no blank
  // area under a short page; the pagination sits at the bottom.
  testWidgets('short tables fill the height and keep pagination at the bottom',
      (tester) async {
    await setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(scaffold(showFilters: false));
    final frame =
        tester.getRect(find.byKey(const ValueKey('app_data_table_frame')));
    final pagination =
        tester.getRect(find.byKey(const ValueKey('app_pagination_bar')));
    expect(pagination.bottom, closeTo(900 - AppSpacing.xl, 1));
    expect(pagination.top - frame.bottom, closeTo(AppSpacing.sm, 1));
    expect(frame.height, greaterThan(600));
    // The rows stay at the top of the card.
    expect(
        tester.getTopLeft(find.text('21 Ann')).dy - frame.top, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide table scrolling fills the height and keeps columns aligned',
      (tester) async {
    await setSize(tester, const Size(800, 900));
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);
    await tester.pumpWidget(scaffold(
        showFilters: false,
        minTableWidth: 1100,
        tableScrollController: horizontal));
    final frame =
        tester.getRect(find.byKey(const ValueKey('app_data_table_frame')));
    expect(frame.height, greaterThan(600));
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getTopLeft(find.text('NAME')).dx,
        tester.getTopLeft(find.text('21 Ann')).dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long tables stay bounded and the final row is reachable',
      (tester) async {
    await setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(scaffold(
        showFilters: false, items: List.generate(100, (i) => 'Person $i')));
    final frame =
        tester.getRect(find.byKey(const ValueKey('app_data_table_frame')));
    expect(frame.height, lessThan(800));
    final scrollable = tester.state<ScrollableState>(find.descendant(
        of: find.byType(ListView), matching: find.byType(Scrollable)));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('120 Person 99'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Back to a short page: the card still fills the same height.
    await tester.pumpWidget(scaffold(showFilters: false));
    expect(
        tester
            .getSize(find.byKey(const ValueKey('app_data_table_frame')))
            .height,
        frame.height);
    expect(tester.takeException(), isNull);
  });

  // A short window scrolls the page, so a short table keeps fitting its
  // rows and the pagination stays right below them, in view.
  testWidgets(
      'short desktop window keeps a fitted table and pagination in view',
      (tester) async {
    await setSize(tester, const Size(1280, 350));
    await tester.pumpWidget(scaffold(showFilters: false));
    expect(
        tester
            .getSize(find.byKey(const ValueKey('app_data_table_frame')))
            .height,
        lessThan(200));
    expect(find.byKey(const ValueKey('app_pagination_bar')).hitTestable(),
        findsOneWidget);
    expect(find.text('2 people'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow list area on a wide screen uses cards', (tester) async {
    await setSize(tester, const Size(720, 900));
    await tester.pumpWidget(scaffold());

    expect(find.byType(CollapsibleFilterTile), findsNothing);
    expect(find.text('card #21'), findsOneWidget);
  });

  testWidgets(
      'loading replaces the list, keeps header, filters and a disabled '
      'pagination bar', (tester) async {
    var pages = 0;
    await setSize(tester, const Size(1280, 800));
    await tester
        .pumpWidget(scaffold(isLoading: true, onPageChanged: (_) => pages++));

    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('21 Ann'), findsNothing);
    // The bar stays (no layout jump) but cannot change page mid-load.
    expect(find.text('2 people'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous page'));
    expect(pages, 0);
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
