import 'package:flutter/material.dart';

import '../feedback/app_loading_view.dart';
import '../layout/list_page_scaffold.dart';
import '../tokens/app_spacing.dart';
import 'app_card_list.dart';
import 'app_data_table.dart';
import 'app_pagination_bar.dart';

/// A list that shows an [AppDataTable] when its own area is at least
/// [cardsBelow] wide and an [AppCardList] otherwise, with an optional
/// [AppPaginationBar] underneath.
///
/// Unlike [ListPageScaffold] it has no header or filters, so it fits inside
/// a tab, a section or a dialog. Needs a bounded height.
class AppAdaptiveList<T> extends StatelessWidget {
  const AppAdaptiveList({
    super.key,
    required this.items,
    required this.columns,
    required this.cardBuilder,
    required this.emptyState,
    this.isLoading = false,
    this.pagination,
    this.onRowTap,
    this.onRefresh,
    this.cardsBelow = ListLayoutBreakpoints.cardsBelow,
  });

  final List<T> items;
  final List<TableColumnDef<T>> columns;
  final Widget Function(T item, int rowNumber) cardBuilder;
  final Widget emptyState;
  final bool isLoading;

  /// Shown under the list when not null.
  final ListPagination? pagination;
  final ValueChanged<T>? onRowTap;
  final Future<void> Function()? onRefresh;

  /// Width of the list area below which cards replace the table.
  final double cardsBelow;

  int _rowNumber(int index) => pagination?.rowNumber(index) ?? index + 1;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const AppLoadingView(useSurface: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCards = constraints.maxWidth < cardsBelow;
        final list = useCards
            ? AppCardList<T>(
                items: items,
                cardBuilder: cardBuilder,
                emptyState: emptyState,
                rowNumberOf: _rowNumber,
                onRefresh: onRefresh,
              )
            : AppDataTable<T>(
                items: items,
                columns: columns,
                emptyState: emptyState,
                rowNumberOf: _rowNumber,
                onRowTap: onRowTap,
                onRefresh: onRefresh,
              );
        return Column(
          children: [
            Expanded(child: list),
            if (pagination != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppPaginationBar.fromState(pagination!),
            ],
          ],
        );
      },
    );
  }
}
