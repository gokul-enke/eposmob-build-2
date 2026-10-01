import 'package:flutter/material.dart';

import '../feedback/app_loading_view.dart';
import '../filters/collapsible_filter_tile.dart';
import '../filters/filter_panel.dart';
import '../list/app_card_list.dart';
import '../list/app_data_table.dart';
import '../list/app_pagination_bar.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Width thresholds used by [ListPageScaffold].
abstract final class ListLayoutBreakpoints {
  /// Below this *screen* width the page uses the mobile layout (collapsible
  /// filters, cards only, tighter padding).
  static const double mobileBelow = 700;

  /// Below this width of the *list area* the wide layout shows cards instead
  /// of the table.
  static const double cardsBelow = 720;

  /// Widest the page content grows before it is centred.
  static const double maxContentWidth = 1440;
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
/// filters        (collapsible tile on mobile)
/// table | cards  (cards on mobile and on narrow list areas)
/// pagination
/// ```
///
/// A page only supplies its header, filter fields, columns, card and data.
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
    this.pagination,
    this.onRowTap,
    this.onRefresh,
  });

  final Widget header;
  final FilterPanel? filters;

  /// Hides [filters] (and the mobile filter tile) when false, e.g. from a
  /// header filter toggle. Applied filters keep working while hidden.
  final bool showFilters;

  /// Required for the mobile layout when [filters] is set.
  final CollapsedFilterTexts? mobileFilterTexts;
  final bool isLoading;
  final List<T> items;
  final List<TableColumnDef<T>> columns;
  final Widget Function(T item, int rowNumber) cardBuilder;
  final Widget emptyState;
  final ListPagination? pagination;
  final ValueChanged<T>? onRowTap;
  final Future<void> Function()? onRefresh;

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
      );

  Widget _listWithPagination({required bool forceCards}) {
    if (isLoading) return const AppLoadingView();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCards = forceCards ||
            constraints.maxWidth < ListLayoutBreakpoints.cardsBelow;
        return Column(
          children: [
            Expanded(child: useCards ? _cards() : _table()),
            if (pagination != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppPaginationBar.fromState(pagination!),
            ],
          ],
        );
      },
    );
  }

  Widget _mobile() {
    final texts = mobileFilterTexts;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          header,
          if (filters != null && showFilters) ...[
            const SizedBox(height: AppSpacing.md),
            if (texts == null)
              filters!
            else
              CollapsibleFilterTile(
                title: texts.title,
                collapsedSubtitle: texts.collapsedSubtitle,
                expandedSubtitle: texts.expandedSubtitle,
                child: filters!.embedded(),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _listWithPagination(forceCards: true)),
        ],
      ),
    );
  }

  Widget _wide() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ListLayoutBreakpoints.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (filters != null && showFilters) ...[
                const SizedBox(height: AppSpacing.lg),
                filters!,
              ],
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _listWithPagination(forceCards: false)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.sizeOf(context).width < ListLayoutBreakpoints.mobileBelow;
    return SafeArea(
      child: ColoredBox(
        color: AppColors.surface,
        child: isMobile ? _mobile() : _wide(),
      ),
    );
  }
}
