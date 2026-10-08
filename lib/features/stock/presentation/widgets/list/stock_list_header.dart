import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import '../../state/stock_list_controller.dart';

PageHeader stockListHeader(
        {required StockListController inputs,
        required ExportController export,
        required bool loading,
        required bool failed,
        required bool hasRows,
        required VoidCallback onExport,
        required VoidCallback onRefresh,
        required VoidCallback onAdd}) =>
    PageHeader(
        icon: Icons.inventory_2_outlined,
        title: 'stock.title'.tr,
        subtitle: 'stock.list_subtitle'.tr,
        onAdd: onAdd,
        addLabel: 'stock.add'.tr,
        addShortLabel: 'stock.list_add_short'.tr,
        actions: [
          HeaderAction(
              key: const ValueKey('stock-filter-toggle'),
              icon: inputs.showFilters
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              label: inputs.showFilters
                  ? 'stock.hide_filters'.tr
                  : 'stock.show_filters'.tr,
              active: inputs.showFilters,
              badge: inputs.hasActiveFilters,
              onPressed: () => inputs.setFiltersVisible(!inputs.showFilters)),
          HeaderAction(
              key: const ValueKey('stock-list-export'),
              icon: Icons.ios_share_rounded,
              label: export.stage ?? 'stock.list_export'.tr,
              busy: export.busy,
              onPressed: !loading && !failed && inputs.initialized && hasRows
                  ? onExport
                  : null),
          HeaderAction(
              key: const ValueKey('stock-list-refresh'),
              icon: Icons.refresh_rounded,
              label: 'stock.list_refresh'.tr,
              onPressed: loading ? null : onRefresh),
        ]);
