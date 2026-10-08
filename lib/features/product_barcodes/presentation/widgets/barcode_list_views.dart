import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../models/barcode_row.dart';

String _display(String? value) =>
    value == null || value.isEmpty || value == 'N/A'
        ? 'product_barcode.na'.tr
        : value;

class BarcodeCopyValue extends StatelessWidget {
  const BarcodeCopyValue({super.key, required this.value, this.label});
  final String? value;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final copy = value == null || value!.isEmpty
        ? null
        : AppSquareIconButton(
            tooltip: 'product_barcode.copy_barcode'.tr,
            icon: Icons.copy_rounded,
            size: AppSizes.compactControl,
            iconSize: 17,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value!));
              if (context.mounted) {
                AppToast.success(context, 'product_barcode.barcode_copied'.tr);
              }
            });
    if (label != null) {
      return InfoRow(label: label!, value: _display(value), trailing: copy);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
          child: Text(_display(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.input)),
      if (copy != null) ...[const SizedBox(width: 4), copy]
    ]);
  }
}

class BarcodeSelectionToolbar extends StatelessWidget {
  const BarcodeSelectionToolbar(
      {super.key,
      required this.pageSelected,
      required this.selectionEnabled,
      required this.selectedCount,
      required this.onSelectPage,
      required this.onClear,
      required this.printing,
      required this.onPrint});
  final bool pageSelected, selectionEnabled, printing;
  final int selectedCount;
  final ValueChanged<bool> onSelectPage;
  final VoidCallback onClear;
  final VoidCallback? onPrint;
  @override
  Widget build(BuildContext context) => AppSurface(
      padding: const EdgeInsets.all(12),
      child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                  value: pageSelected,
                  onChanged: selectionEnabled
                      ? (value) => onSelectPage(value ?? false)
                      : null),
              Flexible(
                  child: Text('product_barcode.select_all_page'.tr,
                      style: AppTextStyles.caption)),
            ]),
            if (selectedCount > 0) ...[
              AppBadge(
                  label: 'product_barcode.selected_count'
                      .trParams({'count': '$selectedCount'})),
              AppPrimaryButton(
                  label: 'product_barcode.print_selected'
                      .trParams({'count': '$selectedCount'}),
                  icon: Icons.print_rounded,
                  height: AppSizes.compactControl,
                  busy: printing,
                  onPressed: onPrint),
              AppOutlinedButton(
                  label: 'product_barcode.clear_selected'.tr,
                  height: AppSizes.compactControl,
                  onPressed: onClear),
            ],
          ]));
}

List<TableColumnDef<BarcodeRow>> barcodeListColumns({
  required bool Function(BarcodeRow) isSelected,
  required void Function(BarcodeRow, bool) onSelected,
  required bool printing,
  required ValueChanged<BarcodeRow> onView,
  required ValueChanged<BarcodeRow> onPrint,
}) =>
    [
      TableColumnDef(
          label: 'product_barcode.col_no'.tr,
          flex: .45,
          cellBuilder: (_, number) => TableCells.number(number)),
      TableColumnDef(
          label: 'product_barcode.select'.tr,
          flex: .7,
          cellBuilder: (row, _) => TableCells.widget(Checkbox(
              value: isSelected(row),
              onChanged: (value) => onSelected(row, value ?? false)))),
      TableColumnDef(
          label: 'product_barcode.product_name'.tr,
          flex: 2.1,
          cellBuilder: (row, _) => TableCells.text(row.displayName)),
      TableColumnDef(
          label: 'product_barcode.barcode'.tr,
          flex: 1.8,
          cellBuilder: (row, _) =>
              TableCells.widget(BarcodeCopyValue(value: row.barcode))),
      TableColumnDef(
          label: 'product_barcode.category'.tr,
          flex: 1.4,
          cellBuilder: (row, _) =>
              TableCells.text(_display(row.product.category?.name))),
      TableColumnDef(
          label: 'product_barcode.qty'.tr,
          flex: .65,
          cellBuilder: (row, _) => TableCells.text(_display(row.quantity))),
      TableColumnDef(
          label: 'product_barcode.col_price'.tr,
          flex: .85,
          cellBuilder: (row, _) => TableCells.text(_display(row.priceDisplay))),
      TableColumnDef(
          label: 'product_barcode.mrp'.tr,
          flex: .85,
          cellBuilder: (row, _) => TableCells.text(_display(row.mrpDisplay))),
      TableColumnDef(
          label: 'product_barcode.col_sku'.tr,
          flex: 1,
          cellBuilder: (row, _) => TableCells.text(_display(row.sku))),
      TableColumnDef(
          label: 'product_barcode.col_action'.tr,
          flex: 1.1,
          cellBuilder: (row, _) =>
              TableCells.widget(Row(mainAxisSize: MainAxisSize.min, children: [
                AppSquareIconButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'product_barcode.view_details'.tr,
                    foreground: AppColors.primary,
                    size: AppSizes.compactControl,
                    iconSize: 19,
                    onPressed: () => onView(row)),
                const SizedBox(width: 8),
                AppSquareIconButton(
                    icon: Icons.print_outlined,
                    tooltip: 'product_barcode.print_barcode_tooltip'.tr,
                    foreground: AppColors.primary,
                    size: AppSizes.compactControl,
                    iconSize: 19,
                    onPressed: printing ? null : () => onPrint(row)),
              ]))),
    ];

class BarcodeListCard extends StatelessWidget {
  const BarcodeListCard(
      {super.key,
      required this.row,
      required this.selected,
      required this.onSelected,
      required this.printing,
      required this.onView,
      required this.onPrint});
  final BarcodeRow row;
  final bool selected, printing;
  final ValueChanged<bool> onSelected;
  final VoidCallback onView, onPrint;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: row.displayName,
      subtitle: _display(row.product.category?.name),
      leading: Checkbox(
          value: selected, onChanged: (value) => onSelected(value ?? false)),
      body: Column(children: [
        InfoGrid(minColumnWidth: 120, maxColumns: 2, children: [
          InfoRow(
              label: 'product_barcode.qty'.tr, value: _display(row.quantity)),
          InfoRow(
              label: 'product_barcode.col_price'.tr,
              value: _display(row.priceDisplay)),
          InfoRow(
              label: 'product_barcode.mrp'.tr, value: _display(row.mrpDisplay)),
          InfoRow(
              label: 'product_barcode.col_sku'.tr, value: _display(row.sku)),
        ]),
        BarcodeCopyValue(
            label: 'product_barcode.barcode'.tr, value: row.barcode),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          AppOutlinedButton(
              label: 'product_barcode.view_details'.tr,
              icon: Icons.visibility_outlined,
              height: AppSizes.compactControl,
              onPressed: onView),
          AppOutlinedButton(
              label: 'product_barcode.print_barcode_tooltip'.tr,
              icon: Icons.print_outlined,
              height: AppSizes.compactControl,
              onPressed: printing ? null : onPrint),
        ]),
      ]));
}
