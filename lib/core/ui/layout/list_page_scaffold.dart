import 'package:flutter/material.dart';

import '../feedback/app_loading_view.dart';
import '../filters/collapsible_filter_tile.dart';
import '../filters/filter_panel.dart';
import '../list/app_card_list.dart';
import '../list/app_data_table.dart';
import '../list/app_pagination_bar.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Width and height thresholds used by [ListPageScaffold].
abstract final class ListLayoutBreakpoints {
  /// Below this *screen* width the page uses the mobile layout (collapsible
  /// filters, cards only, tighter padding).
  static const double mobileBelow = 700;

  /// Below this width of the *list area* the wide layout shows cards instead
  /// of the table.
  static const double cardsBelow = 720;

  /// Widest the page content grows before it is centred.
  static const double maxContentWidth = 1440;

  /// Below this height the whole page scrolls instead of squeezing the list.
  static const double minimumHeight = 600;
}

/// Texts for the mobile collapsible filter tile.
@immutable
class CollapsedFilterTexts {
  const CollapsedFilterTexts({
    required this.title,
    required this.collapsedSubtitle,
    required this.expandedSubtitle,
  });

  final String title;
  final String collapsedSubtitle;
  final String expandedSubtitle;
}

/// The shared listing page layout:
///
/// ```
/// header
/// filters        (collapsible tile on mobile; hideable)
/// toolbar        (optional: totals, chips, bulk actions)
/// table | cards  (cards on mobile and on narrow list areas)
/// pagination
/// ```
///
/// A page only supplies its header, filters, columns, card and data.
class ListPageScaffold<T> extends StatelessWidget {
  const ListPageScaffold({
    super.key,
    required this.header,
    required this.isLoading,
    required this.items,
    required this.columns,
    required this.cardBuilder,
    required this.emptyState,
    this.filters,
    this.showFilters = true,
    this.mobileFilterTexts,
    this.toolbar,
    this.pagination,
    this.onRowTap,
    this.onRefresh,
    this.minTableWidth,
    this.tableScrollController,
  });

  final Widget header;

  /// Usually a [FilterPanel]. On phones a [FilterPanel] with
  /// [mobileFilterTexts] is shown inside a collapsible tile.
  final Widget? filters;

  /// Hides [filters] when false (e.g. from a header filter toggle). Hidden
  /// filters keep their state and keep applying.
  final bool showFilters;
  final CollapsedFilterTexts? mobileFilterTexts;

  /// Extra block between the filters and the list (totals, chips...).
  final Widget? toolbar;
  final bool isLoading;
  final List<T> items;
  final List<TableColumnDef<T>> columns;
  final Widget Function(T item, int rowNumber) cardBuilder;
  final Widget emptyState;
  final ListPagination? pagination;
  final ValueChanged<T>? onRowTap;
  final Future<void> Function()? onRefresh;

  /// The table scrolls horizontally when narrower than this (wide tables
  /// with many columns).
  final double? minTableWidth;

  /// Shows a horizontal scrollbar for [minTableWidth] scrolling.
  final ScrollController? tableScrollController;

  int _rowNumber(int index) => pagination?.rowNumber(index) ?? index + 1;

  Widget _cards() => AppCardList<T>(
        items: items,
        cardBuilder: cardBuilder,
        emptyState: emptyState,
        rowNumberOf: _rowNumber,
        onRefresh: onRefresh,
      );

  Widget _table() => AppDataTable<T>(
        items: items,
        columns: columns,
        emptyState: emptyState,
        rowNumberOf: _rowNumber,
        onRowTap: onRowTap,
        onRefresh: onRefresh,
        minWidth: minTableWidth,
        horizontalController: tableScrollController,
      );

  Widget _listWithPagination({required bool forceCards}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCards = forceCards ||
            constraints.maxWidth < ListLayoutBreakpoints.cardsBelow;
        return Column(
          children: [
            Expanded(
              child: isLoading
                  ? const AppLoadingView()
                  : (useCards ? _cards() : _table()),
            ),
            if (pagination != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppPaginationBar.fromState(pagination!, enabled: !isLoading),
            ],
          ],
        );
      },
    );
  }

  /// Filters (and toolbar) take at most a share of the height and scroll
  /// inside it, so the list always stays visible.
  Widget _capped(Widget child, double maxHeight) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: child),
      );

  List<Widget> _filterAndToolbar({
    required bool mobile,
    required double height,
    required double gap,
  }) {
    final filterBlock = filters;
    final texts = mobileFilterTexts;
    final shownFilters = filterBlock == null
        ? null
        : (mobile && texts != null && filterBlock is FilterPanel)
            ? CollapsibleFilterTile(
                title: texts.title,
                collapsedSubtitle: texts.collapsedSubtitle,
                expandedSubtitle: texts.expandedSubtitle,
                child: filterBlock.embedded(),
              )
            : filterBlock;

    return [
      if (shownFilters != null)
        // Kept in the tree while hidden so pending input survives.
        Visibility(
          visible: showFilters,
          maintainState: true,
          child: Padding(
            padding: EdgeInsets.only(top: gap),
            child:
                _capped(shownFilters, height * (toolbar == null ? .48 : .25)),
          ),
        ),
      if (toolbar != null) ...[
        SizedBox(height: gap),
        _capped(toolbar!, height * .20),
      ],
    ];
  }

  Widget _page({required bool mobile, required double height}) {
    final gap = mobile ? AppSpacing.md : AppSpacing.lg;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        ..._filterAndToolbar(mobile: mobile, height: height, gap: gap),
        SizedBox(height: gap),
        Expanded(child: _listWithPagination(forceCards: mobile)),
      ],
    );
    if (mobile) {
      return Padding(
          padding: const EdgeInsets.all(AppSpacing.md), child: column);
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ListLayoutBreakpoints.maxContentWidth,
          ),
          child: column,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < ListLayoutBreakpoints.mobileBelow;
    return SafeArea(
      child: ColoredBox(
        color: AppColors.surface,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final short =
                bounds.maxHeight < ListLayoutBreakpoints.minimumHeight;
            final height =
                short ? ListLayoutBreakpoints.minimumHeight : bounds.maxHeight;
            final page = _page(mobile: mobile, height: height);
            if (!short) return page;
            return SingleChildScrollView(
              child:
                  SizedBox(height: height, width: bounds.maxWidth, child: page),
            );
          },
        ),
      ),
    );
  }
}
