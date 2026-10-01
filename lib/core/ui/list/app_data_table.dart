import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// One column of an [AppDataTable].
@immutable
class TableColumnDef<T> {
  const TableColumnDef({
    required this.label,
    required this.cellBuilder,
    this.flex = 1,
    this.align = TextAlign.left,
  });

  final String label;
  final double flex;
  final TextAlign align;

  /// Builds the cell for [item]; [rowNumber] is the 1-based number across
  /// pages.
  final Widget Function(T item, int rowNumber) cellBuilder;
}

/// Wide-screen table: canvas header row, white rows with a hairline divider,
/// rounded outer border, scrollable body with optional pull-to-refresh.
///
/// The header lives inside the same scroll view width as the body (both
/// tables share one column layout and the body never draws a scrollbar
/// gutter), so columns stay aligned.
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.items,
    required this.columns,
    required this.emptyState,
    this.rowNumberOf,
    this.onRowTap,
    this.onRefresh,
  });

  final List<T> items;
  final List<TableColumnDef<T>> columns;
  final Widget emptyState;

  /// Maps a 0-based index on this page to the displayed row number. Defaults
  /// to `index + 1`.
  final int Function(int index)? rowNumberOf;
  final ValueChanged<T>? onRowTap;
  final Future<void> Function()? onRefresh;

  Map<int, TableColumnWidth> get _columnWidths => {
        for (var i = 0; i < columns.length; i++)
          i: FlexColumnWidth(columns[i].flex),
      };

  Widget _header() {
    return ColoredBox(
      color: AppColors.canvas,
      child: Table(
        columnWidths: _columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              for (final column in columns)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                  child: Text(
                    column.label,
                    textAlign: column.align,
                    style: AppTextStyles.tableHeader,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(T item, int index) {
    final number = rowNumberOf?.call(index) ?? index + 1;
    final table = Table(
      columnWidths: _columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            for (final column in columns) column.cellBuilder(item, number),
          ],
        ),
      ],
    );

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onRowTap == null ? null : () => onRowTap!(item),
        hoverColor: AppColors.rowHover,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.subtleBorder)),
          ),
          child: table,
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final Widget scrollable = items.isEmpty
        ? SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 310),
              child: Center(child: emptyState),
            ),
          )
        : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _row(items[index], index),
          );

    final body = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: scrollable,
    );

    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, child: body);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    // The border is painted in front of the content: the header and the row
    // Materials fill the full width and would otherwise cover the side edges.
    return DecoratedBox(
      key: const ValueKey('app_data_table_frame'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
            children: [
              _header(),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }
}
