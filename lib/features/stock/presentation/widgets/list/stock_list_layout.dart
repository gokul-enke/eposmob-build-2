import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_stock.dart';
import '../../state/stock_list_controller.dart';
import 'stock_list_columns.dart';
import 'stock_list_filters.dart';
import 'stock_list_mobile_card.dart';

/// Supplies stock presentation to the shared scaffold; owns no provider or
/// navigation state. Every stock action remains a page callback.
Widget stockListLayout({
  required StockListController inputs,
  required Widget header,
  required List<ListStockModelData> rows,
  required bool loading,
  required bool failed,
  required bool canViewPurchasePrice,
  required bool variantEnabled,
  required ScrollController tableScroll,
  required Future<void> Function() onRefresh,
  required Widget Function(ListStockModelData, bool) actions,
  required void Function(ListStockModelData) onCopy,
  required ListPagination pagination,
}) =>
    ListPageScaffold<ListStockModelData>(
      header: header,
      filters: stockListFilters(inputs),
      showFilters: inputs.showFilters,
      mobileFilterTexts: CollapsedFilterTexts(
          title: 'stock.filters_title'.tr,
          collapsedSubtitle: 'stock.list_expand'.tr,
          expandedSubtitle: 'stock.list_filter_hint'.tr),
      isLoading: loading,
      items: rows,
      columns: stockListColumns(
          canViewPurchasePrice: canViewPurchasePrice,
          variantEnabled: variantEnabled,
          actions: (stock) => actions(stock, false),
          onCopy: onCopy),
      cardBuilder: (stock, _) => StockListMobileCard(
          stock: stock,
          variantEnabled: variantEnabled,
          canViewPurchasePrice: canViewPurchasePrice,
          actions: actions(stock, true),
          onCopy: () => onCopy(stock)),
      emptyState: AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: failed
              ? 'stock.list_load_failed'.tr
              : (inputs.hasActiveFilters
                  ? 'stock.no_stock_filtered'.tr
                  : 'stock.no_stock_data'.tr),
          subtitle:
              inputs.hasActiveFilters ? 'stock.try_adjusting_filters'.tr : null,
          action: failed
              ? AppOutlinedButton(
                  label: 'stock.list_refresh'.tr, onPressed: onRefresh)
              : (inputs.hasActiveFilters
                  ? AppOutlinedButton(
                      label: 'stock.reset_filters_btn'.tr,
                      onPressed: inputs.reset)
                  : null)),
      minTableWidth: 1480,
      tableScrollController: tableScroll,
      onRefresh: onRefresh,
      pagination: pagination,
    );
