import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../resources/color_manager.dart';
import '../app_colors.dart';
import '../app_surface.dart';

abstract final class ListLayoutBreakpoints {
  static const mobile = 700.0;
  static const table = 720.0;
  static const header = 560.0;
  static const actions = 900.0;
  static const oneFilter = 540.0;
  static const fourFilters = 940.0;
  static const pagination = 440.0;
  static const maxWidth = 1440.0;
  static const minimumHeight = 600.0;
}

class TableColumnDef<T> {
  const TableColumnDef(
      {required this.label, required this.cellBuilder, this.flex = 1});
  final String label;
  final double flex;
  final Widget Function(T item, int rowNumber) cellBuilder;
}

abstract final class TableCells {
  static Widget text(String value, {Color color = AppColors.body}) => Text(
      value.trim().isEmpty ? '—' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500));
  static Widget amount(double value) => text(value.toStringAsFixed(2),
      color: value < 0 ? AppColors.red : AppColors.green);
  static Widget viewButton(VoidCallback onPressed) => OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.visibility_outlined, size: 16),
      label: Text('list.view'.tr),
      style: OutlinedButton.styleFrom(
          foregroundColor: ColorManager.kPrimaryColor,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control))));
  static Widget identity(String name) => Row(children: [
        Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(12)),
            child: Text(
                name.trim().isEmpty ? '#' : name.trim()[0].toUpperCase(),
                style: const TextStyle(
                    color: ColorManager.kPrimaryColor,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: text(name)),
      ]);
}

class ListPageScaffold<T> extends StatelessWidget {
  const ListPageScaffold(
      {super.key,
      required this.header,
      this.filters,
      this.toolbar,
      this.tableScrollController,
      this.showFilters = true,
      required this.isLoading,
      required this.items,
      required this.columns,
      required this.cardBuilder,
      required this.emptyState,
      required this.onRefresh,
      required this.currentPage,
      required this.totalPages,
      required this.itemsPerPage,
      required this.countLabel,
      required this.onPageChanged,
      this.onItemTap,
      this.tableMinWidth = ListLayoutBreakpoints.table});

  /// Minimum content width; desktop tables scroll horizontally below this.
  final double tableMinWidth;
  final Widget header;
  final Widget? filters;
  final Widget? toolbar;
  final ScrollController? tableScrollController;
  final bool showFilters;
  final bool isLoading;
  final List<T> items;
  final List<TableColumnDef<T>> columns;
  final Widget Function(T, int) cardBuilder;
  final Widget emptyState;
  final Future<void> Function() onRefresh;
  final int currentPage, totalPages, itemsPerPage;
  final String countLabel;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<T>? onItemTap;

  int number(int index) => index + 1 + (currentPage - 1) * itemsPerPage;
  Widget _row(List<Widget> cells, {bool heading = false}) => Row(
      children: List.generate(
          columns.length,
          (index) => Expanded(
              flex: (columns[index].flex * 100).round(),
              child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: heading ? 13 : 9),
                  child: cells[index]))));

  @override
  Widget build(BuildContext context) =>
      SafeArea(child: LayoutBuilder(builder: (context, bounds) {
        final mobile = bounds.maxWidth < ListLayoutBreakpoints.mobile;
        final shortViewport =
            bounds.maxHeight < ListLayoutBreakpoints.minimumHeight;
        final contentHeight = shortViewport
            ? ListLayoutBreakpoints.minimumHeight
            : bounds.maxHeight;
        final page = ColoredBox(
            color: AppColors.surface,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: ListLayoutBreakpoints.maxWidth),
                    child: Padding(
                        padding: EdgeInsets.all(
                            mobile ? AppSpacing.small : AppSpacing.page),
                        child: Column(children: [
                          header,
                          const SizedBox(height: AppSpacing.medium),
                          if (filters != null)
                            Visibility(
                                visible: showFilters,
                                // Preserve pending searches and field state while
                                // hiding the controls.
                                maintainState: true,
                                child: Column(children: [
                                  ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight: contentHeight *
                                              (toolbar == null ? .48 : .25)),
                                      child: SingleChildScrollView(
                                          child: filters!)),
                                  const SizedBox(height: AppSpacing.medium)
                                ])),
                          if (toolbar != null) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight: contentHeight * .20),
                              child: SingleChildScrollView(child: toolbar!),
                            ),
                            const SizedBox(height: AppSpacing.medium)
                          ],
                          Expanded(
                              child: isLoading
                                  ? const AppSurface(
                                      child: Center(
                                          child: CircularProgressIndicator
                                              .adaptive()))
                                  : LayoutBuilder(builder: (context, size) {
                                      final table = !mobile;
                                      final body = ScrollConfiguration(
                                          behavior: ScrollConfiguration.of(context)
                                              .copyWith(dragDevices: {
                                            PointerDeviceKind.mouse,
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.stylus,
                                            PointerDeviceKind.trackpad
                                          }),
                                          child: RefreshIndicator(
                                              onRefresh: onRefresh,
                                              child: items.isEmpty
                                                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                                                      emptyState
                                                    ])
                                                  : ListView.separated(
                                                      physics: const AlwaysScrollableScrollPhysics(
                                                          parent:
                                                              BouncingScrollPhysics()),
                                                      itemCount: items.length,
                                                      separatorBuilder: (_, __) => table
                                                          ? const Divider(
                                                              height: 1,
                                                              color: AppColors
                                                                  .subtleBorder)
                                                          : const SizedBox(
                                                              height: 10),
                                                      itemBuilder: (_, index) =>
                                                          table ? Material(color: AppColors.surface, child: InkWell(onTap: onItemTap == null ? null : () => onItemTap!(items[index]), child: _row(columns.map((col) => col.cellBuilder(items[index], number(index))).toList()))) : cardBuilder(items[index], number(index)))));
                                      if (!table) return body;
                                      final tableContent = ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.card),
                                          child: DecoratedBox(
                                              position:
                                                  DecorationPosition.foreground,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppRadius.card),
                                                  border: Border.all(
                                                      color: AppColors.border)),
                                              child: Column(children: [
                                                ColoredBox(
                                                    color: AppColors.canvas,
                                                    child: _row(
                                                        columns
                                                            .map((col) => Text(
                                                                col.label
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                    color: AppColors
                                                                        .muted,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700)))
                                                            .toList(),
                                                        heading: true)),
                                                Expanded(child: body)
                                              ])));
                                      final scrollView = SingleChildScrollView(
                                        controller: tableScrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: size.maxWidth < tableMinWidth
                                              ? tableMinWidth
                                              : size.maxWidth,
                                          height: size.maxHeight,
                                          child: tableContent,
                                        ),
                                      );
                                      return tableScrollController == null
                                          ? scrollView
                                          : Scrollbar(
                                              controller: tableScrollController,
                                              thumbVisibility: true,
                                              interactive: true,
                                              notificationPredicate:
                                                  (notification) =>
                                                      notification
                                                          .metrics.axis ==
                                                      Axis.horizontal,
                                              child: scrollView,
                                            );
                                    })),
                          const SizedBox(height: 8),
                          AppSurface(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: LayoutBuilder(builder: (context, size) {
                                final count = Text(countLabel,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12));
                                final pages = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton.outlined(
                                          tooltip:
                                              'pagination.previous_page'.tr,
                                          onPressed: currentPage > 1 &&
                                                  !isLoading
                                              ? () =>
                                                  onPageChanged(currentPage - 1)
                                              : null,
                                          icon: const Icon(
                                              Icons.chevron_left_rounded)),
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          child: Text(
                                              'pagination.page_of'.trParams({
                                                'current': '$currentPage',
                                                'total': '$totalPages'
                                              }),
                                              style: const TextStyle(
                                                  color: AppColors.body,
                                                  fontSize: 12))),
                                      IconButton.outlined(
                                          tooltip: 'pagination.next_page'.tr,
                                          onPressed: currentPage < totalPages &&
                                                  !isLoading
                                              ? () =>
                                                  onPageChanged(currentPage + 1)
                                              : null,
                                          icon: const Icon(
                                              Icons.chevron_right_rounded))
                                    ]);
                                return size.maxWidth <
                                        ListLayoutBreakpoints.pagination
                                    ? Column(children: [
                                        count,
                                        const SizedBox(height: 8),
                                        pages
                                      ])
                                    : Row(children: [
                                        Expanded(child: count),
                                        const SizedBox(width: 12),
                                        pages
                                      ]);
                              })),
                        ])))));
        if (shortViewport) {
          return SingleChildScrollView(
              child: SizedBox(
                  height: contentHeight, width: bounds.maxWidth, child: page));
        }
        return page;
      }));
}
