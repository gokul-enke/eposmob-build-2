import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/buttons/app_buttons.dart';
import 'package:pos_machine/core/ui/display/app_badge.dart';
import 'package:pos_machine/core/ui/display/app_metric.dart';
import 'package:pos_machine/core/ui/feedback/app_empty_state.dart';
import 'package:pos_machine/core/ui/filters/filter_field.dart';
import 'package:pos_machine/core/ui/filters/filter_panel.dart';
import 'package:pos_machine/core/ui/layout/list_page_scaffold.dart';
import 'package:pos_machine/core/ui/layout/page_header.dart';
import 'package:pos_machine/core/ui/list/app_data_table.dart';
import 'package:pos_machine/core/ui/list/app_list_card.dart';
import 'package:pos_machine/core/ui/list/app_pagination_bar.dart';
import 'package:pos_machine/core/ui/list/table_cells.dart';
import '../../../../../controllers/sidebar_controller.dart';
import '../../../domain/models/purchase_order_model.dart';
import '../../state/purchase_order_list_controller.dart';
import 'purchase_list_filter_fields.dart';

class PurchaseOrderListView extends StatelessWidget {
  const PurchaseOrderListView(
      {super.key,
      required this.controller,
      required this.currency,
      required this.onCreate,
      required this.onOpen,
      required this.export,
      required this.onExport,
      required this.onReset,
      required this.scrollController});
  final PurchaseOrderListController controller;
  final String currency;
  final VoidCallback onCreate, onExport;
  final Future<void> Function() onReset;
  final Future<void> Function(PurchaseOrderData, int) onOpen;
  final ExportController export;
  final ScrollController scrollController;

  static bool canReceive(PurchaseOrderData item) {
    final parts = item.itemsReceived?.split('/');
    if (parts == null || parts.length != 2) return false;
    final received = int.tryParse(parts[0].trim()) ?? 0;
    final total = int.tryParse(parts[1].trim()) ?? 0;
    return received < total && total > 0;
  }

  static String receivedLabel(PurchaseOrderData item) =>
      item.itemsReceived?.isNotEmpty == true
          ? item.itemsReceived!
          : 'purchase_order.items_received_default'.tr;
  Widget _badge(PurchaseOrderData item) {
    final parts = receivedLabel(item).split('/');
    final received = parts.length == 2 ? int.tryParse(parts[0].trim()) ?? 0 : 0;
    final total = parts.length == 2 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return AppBadge(
        label: receivedLabel(item),
        tone: total > 0 && received == total
            ? AppBadgeTone.success
            : total > 0 && received > 0 && received < total
                ? AppBadgeTone.warning
                : AppBadgeTone.neutral);
  }

  Widget _actions(PurchaseOrderData item) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        AppOutlinedButton(
            key: ValueKey('purchase-order-view-${item.id}'),
            label: 'list.view'.tr,
            icon: Icons.visibility_outlined,
            height: 36,
            onPressed: () =>
                onOpen(item, SideBarController.purchaseDetailsScreenIndex)),
        if (canReceive(item))
          AppOutlinedButton(
              key: ValueKey('purchase-order-receive-${item.id}'),
              label: 'purchase_order.receive_col'.tr,
              icon: Icons.add,
              height: 36,
              onPressed: () => onOpen(
                  item, SideBarController.createPurchaseOrderScreenIndex)),
      ]);
  FilterFieldDef _picker(
          String label,
          IconData icon,
          TextEditingController input,
          TextEditingController search,
          List<String> options) =>
      CustomFilterField(
          child: PurchaseListPicker(
              label: label,
              icon: icon,
              value: input.text,
              search: search,
              options: options,
              onChanged: (value) {
                controller.update(() => input.text = value);
                controller.fetchPurchases();
              }));
  FilterFieldDef _date(String label, TextEditingController input) =>
      CustomFilterField(
          child: PurchaseListDateField(
              label: label,
              hint: 'purchase_order.date_format_hint'.tr,
              controller: input,
              onChanged: (value) {
                controller.update(() => input.text = value);
                controller.fetchPurchases();
              }));
  @override
  Widget build(BuildContext context) {
    final rows = controller.purchaseOrdersList;
    final total = rows.fold<double>(
        0, (sum, e) => sum + (double.tryParse(e.amountTotal ?? '0') ?? 0));
    return ListPageScaffold<PurchaseOrderData>(
      header: PageHeader(
          icon: Icons.receipt_long_outlined,
          title: 'purchase_order.title'.tr,
          subtitle: 'purchase_order.subtitle'.tr,
          onAdd: onCreate,
          addLabel: 'purchase_order.create_purchase_order_btn'.tr,
          addShortLabel: 'purchase_order.add_short'.tr,
          actions: [
            HeaderAction.filters(
                key: const ValueKey('purchase-order-filter-toggle'),
                showFilters: controller.showFilters,
                showLabel: 'list.filters'.tr,
                hideLabel: 'list.hide_filters'.tr,
                badge: controller.hasActiveFilters,
                onPressed: () => controller.update(
                    () => controller.showFilters = !controller.showFilters)),
            HeaderAction(
                key: const ValueKey('purchase-order-export'),
                icon: Icons.ios_share_rounded,
                label: export.stage ?? 'list.export'.tr,
                busy: export.busy,
                onPressed:
                    controller.initLoading || rows.isEmpty ? null : onExport),
            HeaderAction(
                icon: Icons.refresh_rounded,
                label: 'list.refresh'.tr,
                onPressed: controller.initLoading ? null : onReset),
          ]),
      showFilters: controller.showFilters,
      filters: FilterPanel(
          key: const ValueKey('purchase-order-filters'),
          title: 'purchase_order.find_orders'.tr,
          hint: 'purchase_order.filter_hint'.tr,
          resetLabel: 'purchase_order.reset'.tr,
          onReset: onReset,
          onSearch: () => controller.fetchPurchases(),
          fields: [
            _picker(
                'purchase_order.supplier'.tr,
                Icons.local_shipping_outlined,
                controller.supplierController,
                controller.supplierSearchController,
                controller.suppliers),
            _picker(
                'purchase_order.store'.tr,
                Icons.storefront_outlined,
                controller.storeController,
                controller.storeSearchController,
                controller.stores),
            _date('purchase_order.from_date'.tr, controller.fromDateController),
            _date('purchase_order.to_date'.tr, controller.toDateController),
          ]),
      toolbar: AppMetricStrip(metrics: [
        AppMetric(
            icon: Icons.payments_outlined,
            label: 'purchase_order.page_total'.tr,
            value: '$currency ${total.toStringAsFixed(2)}')
      ]),
      isLoading: controller.initLoading,
      items: rows,
      minTableWidth: 1050,
      tableScrollController: scrollController,
      onRefresh: onReset,
      pagination: ListPagination(
          currentPage: controller.listPurchaseOrderCurrentPage,
          totalPages: controller.listPurchaseOrderTotalPages,
          itemsPerPage: 15,
          countLabel:
              'purchase_order.page_count'.trParams({'count': '${rows.length}'}),
          onPageChanged: (page) => controller.fetchPurchases(page: page)),
      emptyState: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'purchase_order.no_orders_found'.tr),
      columns: [
        TableColumnDef(
            label: 'purchase_order.sl_col'.tr,
            flex: .4,
            cellBuilder: (_, n) => TableCells.number(n)),
        TableColumnDef(
            label: 'purchase_order.purchase_date'.tr,
            cellBuilder: (e, _) => TableCells.text(e.purchaseDate ?? '')),
        TableColumnDef(
            label: 'purchase_order.store'.tr,
            cellBuilder: (e, _) => TableCells.text(e.store?.name ?? '')),
        TableColumnDef(
            label: 'purchase_order.supplier'.tr,
            flex: 1.3,
            cellBuilder: (e, _) => TableCells.text(e.supplier?.name ?? '')),
        TableColumnDef(
            label: 'purchase_order.total_price'.tr,
            cellBuilder: (e, _) =>
                TableCells.text('$currency ${e.amountTotal ?? '0'}')),
        TableColumnDef(
            label: 'purchase_order.received_items_col'.tr,
            flex: .8,
            cellBuilder: (e, _) => TableCells.widget(_badge(e))),
        TableColumnDef(
            label: 'purchase_order.action_col'.tr,
            flex: 1.5,
            cellBuilder: (e, _) => TableCells.widget(_actions(e))),
      ],
      cardBuilder: (e, n) => AppListCard(
          title: e.purchaseDate ?? '—',
          subtitle: '${e.supplier?.name ?? '—'} · #$n',
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.storefront_outlined,
                  label: 'purchase_order.store'.tr,
                  value: e.store?.name ?? '—'),
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'purchase_order.total_price'.tr,
                  value: '$currency ${e.amountTotal ?? '0'}'),
            ]),
            const SizedBox(height: 10),
            _badge(e),
            const SizedBox(height: 10),
            _actions(e),
          ])),
    );
  }
}
