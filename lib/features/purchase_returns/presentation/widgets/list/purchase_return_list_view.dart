import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/buttons/app_buttons.dart';
import 'package:pos_machine/core/ui/display/app_badge.dart';
import 'package:pos_machine/core/ui/display/app_metric.dart';
import 'package:pos_machine/core/ui/feedback/app_empty_state.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/core/ui/filters/filter_field.dart';
import 'package:pos_machine/core/ui/filters/filter_panel.dart';
import 'package:pos_machine/core/ui/layout/list_page_scaffold.dart';
import 'package:pos_machine/core/ui/layout/page_header.dart';
import 'package:pos_machine/core/ui/list/app_data_table.dart';
import 'package:pos_machine/core/ui/list/app_list_card.dart';
import 'package:pos_machine/core/ui/list/app_pagination_bar.dart';
import 'package:pos_machine/core/ui/list/table_cells.dart';
import 'package:pos_machine/features/purchases/presentation/widgets/list/purchase_list_filter_fields.dart';
import '../../../domain/models/purchase_return.dart';
import '../../state/purchase_return_list_controller.dart';

class PurchaseReturnListView extends StatelessWidget {
  const PurchaseReturnListView(
      {super.key,
      required this.controller,
      required this.currency,
      required this.onCreate,
      required this.onView,
      required this.export,
      required this.onExport,
      required this.onReset,
      required this.scrollController});
  final PurchaseReturnListController controller;
  final String currency;
  final VoidCallback onCreate, onExport, onReset;
  final ValueChanged<PurchaseReturnData> onView;
  final ExportController export;
  final ScrollController scrollController;
  String _amount(PurchaseReturnData e) =>
      '$currency ${e.totalAmount?.toStringAsFixed(2) ?? '0.00'}';
  String _status(PurchaseReturnData e) => e.status == 'completed'
      ? 'purchase_return.status_completed'.tr
      : 'purchase_return.status_pending'.tr;
  Widget _badge(PurchaseReturnData e) => AppBadge(
      label: _status(e),
      tone: e.status == 'completed'
          ? AppBadgeTone.success
          : AppBadgeTone.warning);
  FilterFieldDef _date(String label, TextEditingController input) =>
      CustomFilterField(
          child: PurchaseListDateField(
              label: label,
              hint: 'purchase_return.date_hint'.tr,
              controller: input,
              onChanged: (value) {
                controller.update(() => input.text = value);
                controller.fetchReturns(page: 1);
              }));
  @override
  Widget build(BuildContext context) {
    final rows = controller.purchaseReturnsList;
    return ListPageScaffold<PurchaseReturnData>(
      header: PageHeader(
          icon: Icons.assignment_return_outlined,
          title: 'purchase_return.title'.tr,
          subtitle: 'purchase_return.subtitle'.tr,
          onAdd: onCreate,
          addLabel: 'purchase_return.create_btn'.tr,
          addShortLabel: 'purchase_order.add_short'.tr,
          actions: [
            HeaderAction(
                key: const ValueKey('purchase-return-filter-toggle'),
                icon: Icons.filter_alt_outlined,
                label: 'purchase_order.filters'.tr,
                active: controller.showFilters,
                badge: controller.hasActiveFilters(),
                onPressed: () => controller.update(
                    () => controller.showFilters = !controller.showFilters)),
            HeaderAction(
                key: const ValueKey('purchase-return-export'),
                icon: Icons.ios_share_rounded,
                label: export.stage ?? 'list.export'.tr,
                busy: export.busy,
                onPressed: controller.isLoading ||
                        controller.loadError != null ||
                        rows.isEmpty
                    ? null
                    : onExport),
            HeaderAction(
                icon: Icons.refresh_rounded,
                label: 'list.refresh'.tr,
                onPressed: controller.isLoading
                    ? null
                    : () => controller.fetchReturns()),
          ]),
      showFilters: controller.showFilters,
      filters: FilterPanel(
          key: const ValueKey('purchase-return-filters'),
          title: 'purchase_return.find_returns'.tr,
          hint: 'purchase_return.filter_hint'.tr,
          resetLabel: 'purchase_order.reset'.tr,
          onReset: onReset,
          onSearch: () => controller.fetchReturns(page: 1),
          fields: [
            CustomFilterField(
                child: PurchaseListPicker(
                    label: 'purchase_return.supplier'.tr,
                    icon: Icons.local_shipping_outlined,
                    value: controller.supplierController.text,
                    options: controller.suppliers,
                    search: controller.supplierSearchController,
                    onChanged: (value) {
                      controller.update(
                          () => controller.supplierController.text = value);
                      controller.fetchReturns(page: 1);
                    })),
            _date(
                'purchase_return.from_date'.tr, controller.fromDateController),
            _date('purchase_return.to_date'.tr, controller.toDateController),
          ]),
      items: rows,
      isLoading: controller.isLoading,
      minTableWidth: 1050,
      tableScrollController: scrollController,
      onRefresh: controller.fetchReturns,
      pagination: ListPagination(
          currentPage: controller.purchaseReturnCurrentPage,
          totalPages: controller.purchaseReturnTotalPages,
          itemsPerPage: 15,
          countLabel: 'purchase_return.page_count'
              .trParams({'count': '${rows.length}'}),
          onPageChanged: (page) => controller.fetchReturns(page: page)),
      emptyState: AppEmptyState(
          icon: controller.loadError == null
              ? Icons.assignment_return_outlined
              : Icons.error_outline,
          title: controller.loadError ?? 'purchase_return.no_returns_found'.tr,
          subtitle: controller.loadError == null
              ? 'purchase_return.start_return_hint'.tr
              : null,
          action: controller.loadError == null
              ? null
              : AppOutlinedButton(
                  label: 'restaurant.retry'.tr,
                  onPressed: controller.fetchReturns)),
      columns: [
        TableColumnDef(
            label: 'purchase_return.reference'.tr,
            cellBuilder: (e, _) => TableCells.text(e.reference ?? '#${e.id}')),
        TableColumnDef(
            label: 'purchase_return.voucher_number'.tr,
            cellBuilder: (e, _) => TableCells.text(e.voucherNumber ?? '-')),
        TableColumnDef(
            label: 'purchase_return.supplier'.tr,
            flex: 1.3,
            cellBuilder: (e, _) => TableCells.text(e.supplier?.name ?? '-')),
        TableColumnDef(
            label: 'purchase_return.return_date'.tr,
            cellBuilder: (e, _) => TableCells.text(e.returnDate ?? '-')),
        TableColumnDef(
            label: 'purchase_return.total_amount'.tr,
            cellBuilder: (e, _) => TableCells.text(_amount(e))),
        TableColumnDef(
            label: 'purchase_return.status'.tr,
            cellBuilder: (e, _) => TableCells.widget(_badge(e))),
        TableColumnDef(
            label: 'purchase_order.action_col'.tr,
            cellBuilder: (e, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => onView(e))),
      ],
      cardBuilder: (e, _) => AppListCard(
          title: e.reference ?? '#${e.id}',
          subtitle: '${e.supplier?.name ?? '-'} • ${e.returnDate ?? ''}',
          trailing: IconButton(
              key: ValueKey('purchase-return-copy-${e.id}'),
              tooltip: 'purchase_return.copy_reference'.tr,
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: e.reference ?? e.id.toString()));
                if (context.mounted) {
                  AppToast.success(context, 'purchase_return.copy_success'.tr);
                }
              }),
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _badge(e),
            const SizedBox(height: 10),
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.receipt_outlined,
                  label: 'purchase_return.voucher_number'.tr,
                  value: e.voucherNumber ?? '-'),
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'purchase_return.total_amount'.tr,
                  value: _amount(e)),
            ]),
          ]),
          actionLabel: 'list.view'.tr,
          actionIcon: Icons.visibility_outlined,
          onAction: () => onView(e)),
    );
  }
}
