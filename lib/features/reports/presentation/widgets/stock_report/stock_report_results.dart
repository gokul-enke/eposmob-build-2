import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/models/stock_report.dart';
import '../../../domain/stock_report_display.dart';

String _tr(String key) => 'stock_report.$key'.tr;
String _stock(StockReportData row) =>
    '${row.totalQuantity ?? 0} ${row.unit ?? 'general.default_unit'.tr}';

List<TableColumnDef<StockReportData>> stockReportColumns(
        {required bool showCosts}) =>
    [
      TableColumnDef(
          label: _tr('col_no'),
          flex: .45,
          cellBuilder: (_, number) => TableCells.number(number)),
      TableColumnDef(
          label: _tr('col_product_name'),
          flex: 2,
          cellBuilder: (r, _) => TableCells.text(r.name)),
      TableColumnDef(
          label: _tr('col_category'),
          cellBuilder: (r, _) => TableCells.text(r.categoryName ?? '—')),
      TableColumnDef(
          label: _tr('col_stores'),
          flex: .6,
          cellBuilder: (r, _) =>
              TableCells.widget(AppBadge(label: '${r.storeCount ?? 1}'))),
      TableColumnDef(
          label: _tr('col_barcode'),
          flex: 1.5,
          cellBuilder: (r, _) =>
              TableCells.widget(StockBarcode(value: r.barcode))),
      TableColumnDef(
          label: _tr('col_retail_price'),
          cellBuilder: (r, _) =>
              TableCells.text(stockReportMoney(r.retailPrice))),
      TableColumnDef(
          label: _tr('col_mrp'),
          cellBuilder: (r, _) => TableCells.text(stockReportMoney(r.mrp))),
      if (showCosts)
        TableColumnDef(
            label: _tr('col_purchase_price'),
            cellBuilder: (r, _) =>
                TableCells.text(stockReportMoney(r.purchasePrice))),
      TableColumnDef(
          label: _tr('col_current_stock'),
          cellBuilder: (r, _) => TableCells.text(_stock(r))),
      if (showCosts)
        TableColumnDef(
            label: _tr('col_stock_value'),
            cellBuilder: (r, _) =>
                TableCells.text(stockReportMoney(r.stockValue))),
      TableColumnDef(
          label: _tr('col_retail_value'),
          cellBuilder: (r, _) =>
              TableCells.text(stockReportMoney(r.retailValue))),
      TableColumnDef(
          label: _tr('col_expiry_date'),
          cellBuilder: (r, _) =>
              TableCells.text(stockReportExpiry(r.expiryDate))),
    ];

class StockBarcode extends StatelessWidget {
  const StockBarcode({super.key, required this.value});
  final String? value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(value ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body)),
        if (value?.isNotEmpty == true)
          IconButton(
              tooltip: _tr('col_barcode'),
              icon: const Icon(Icons.copy_outlined, size: 17),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value!));
                if (context.mounted) {
                  AppToast.success(context, _tr('barcode_copied'));
                }
              }),
      ]);
}

class StockReportCard extends StatelessWidget {
  const StockReportCard(
      {super.key,
      required this.row,
      required this.number,
      required this.showCosts});
  final StockReportData row;
  final int number;
  final bool showCosts;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: row.name,
      subtitle: '${_tr('col_no')}: $number • ${row.categoryName ?? '—'}',
      trailing: AppBadge(
          label: '${row.storeCount ?? 1}', semanticLabel: _tr('col_stores')),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StockBarcode(value: row.barcode),
        InfoRow(label: _tr('col_current_stock'), value: _stock(row)),
        InfoRow(
            label: _tr('col_retail_price'),
            value: stockReportMoney(row.retailPrice)),
        InfoRow(label: _tr('col_mrp'), value: stockReportMoney(row.mrp)),
        if (showCosts) ...[
          InfoRow(
              label: _tr('col_purchase_price'),
              value: stockReportMoney(row.purchasePrice)),
          InfoRow(
              label: _tr('col_stock_value'),
              value: stockReportMoney(row.stockValue)),
        ],
        InfoRow(
            label: _tr('col_retail_value'),
            value: stockReportMoney(row.retailValue)),
        InfoRow(
            label: _tr('col_expiry_date'),
            value: stockReportExpiry(row.expiryDate)),
      ]));
}

class StockReportTotals extends StatelessWidget {
  const StockReportTotals(
      {super.key, required this.summary, required this.showCosts});
  final StockReportSummary summary;
  final bool showCosts;
  @override
  Widget build(BuildContext context) {
    final metrics = [
      AppMetric(
          icon: Icons.inventory_2_outlined,
          label: _tr('total_stocked_units'),
          value: '${summary.totalUnits ?? 0}'),
      if (showCosts)
        AppMetric(
            icon: Icons.monetization_on_outlined,
            label: _tr('total_stock_value'),
            value: stockReportMoney(summary.totalStockValue)),
      AppMetric(
          icon: Icons.shopping_bag_outlined,
          label: _tr('total_retail_value'),
          value: stockReportMoney(summary.totalRetailValue)),
    ];
    return LayoutBuilder(
        builder: (_, constraints) =>
            constraints.maxWidth < ListLayoutBreakpoints.cardsBelow
                ? AppSurface(
                    shadow: false,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.xxs),
                        metrics[i],
                      ],
                    ]))
                : AppMetricStrip(metrics: metrics));
  }
}
