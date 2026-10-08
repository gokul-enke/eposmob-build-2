import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../../../domain/models/non_stock_report.dart';

String _tr(String key) => 'non_stock_report.$key'.tr;
String _value(Object? value, [String fallback = '—']) =>
    value?.toString() ?? fallback;

/// Status comes from the endpoint; preserve its original text classification.
class NonStockStatus extends StatelessWidget {
  const NonStockStatus({super.key, required this.status});
  final String? status;
  @override
  Widget build(BuildContext context) => AppBadge(
      label: UiCodeLabels.stockStatus(status),
      tone: (status ?? '').toLowerCase().contains('out of stock')
          ? AppBadgeTone.danger
          : (status ?? '').toLowerCase().contains('low stock')
              ? AppBadgeTone.warning
              : AppBadgeTone.neutral);
}

class NonStockBarcode extends StatelessWidget {
  const NonStockBarcode({super.key, required this.barcode});
  final String? barcode;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Tooltip(
                message: _value(barcode),
                child: Text(_value(barcode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body))),
        if (barcode != null && barcode!.isNotEmpty && barcode != '-')
          IconButton(
              tooltip: _tr('barcode_copied'),
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.copy_outlined,
                  size: 16, color: AppColors.muted),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: barcode!));
                if (context.mounted) {
                  AppToast.success(context, _tr('barcode_copied'));
                }
              }),
      ]);
}

List<TableColumnDef<NonStockReportData>> nonStockReportColumns() => [
      TableColumnDef(
          label: _tr('col_no'),
          flex: .45,
          cellBuilder: (_, n) => TableCells.number(n)),
      TableColumnDef(
          label: _tr('col_product_name'),
          flex: 2,
          cellBuilder: (r, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectableText(r.name, style: AppTextStyles.body))),
      TableColumnDef(
          label: _tr('col_category'),
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.text(_value(r.categoryName))),
      TableColumnDef(
          label: _tr('col_store'),
          flex: 1.3,
          cellBuilder: (r, _) => TableCells.text(_value(r.store))),
      TableColumnDef(
          label: _tr('col_barcode'),
          flex: 1.5,
          cellBuilder: (r, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: NonStockBarcode(barcode: r.barcode))),
      TableColumnDef(
          label: _tr('col_current_stock'),
          cellBuilder: (r, _) => TableCells.text(_value(r.totalQuantity, '0'))),
      TableColumnDef(
          label: _tr('col_reorder_level'),
          cellBuilder: (r, _) => TableCells.text(_value(r.reorderLevel, '0'))),
      TableColumnDef(
          label: _tr('col_unit'),
          flex: .6,
          cellBuilder: (r, _) => TableCells.text(_value(r.unit))),
      TableColumnDef(
          label: _tr('col_status'),
          flex: 1.15,
          cellBuilder: (r, _) =>
              TableCells.widget(NonStockStatus(status: r.status))),
    ];

class NonStockReportCard extends StatelessWidget {
  const NonStockReportCard(
      {super.key, required this.row, required this.number});
  final NonStockReportData row;
  final int number;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: '#$number  ${row.name}',
      subtitle: _value(row.categoryName),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NonStockStatus(status: row.status),
        InfoGrid(minColumnWidth: 130, maxColumns: 2, children: [
          InfoRow(label: _tr('store_stat'), value: _value(row.store)),
          InfoRow(label: _tr('unit_stat'), value: _value(row.unit)),
          InfoRow(
              label: _tr('stock_stat'), value: _value(row.totalQuantity, '0')),
          InfoRow(
              label: _tr('reorder_stat'), value: _value(row.reorderLevel, '0')),
        ]),
        Text(_tr('barcode_stat'), style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        NonStockBarcode(barcode: row.barcode),
      ]));
}
