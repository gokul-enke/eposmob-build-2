import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/models/consumed_stocks_report.dart';

String _tr(String key) => 'consumed_stocks_report.$key'.tr;
String _value(Object? value) => value?.toString() ?? '—';
List<TableColumnDef<ConsumedStockData>> consumedStocksColumns() => [
      TableColumnDef(
          label: _tr('col_no'),
          flex: .4,
          cellBuilder: (_, n) => TableCells.number(n)),
      TableColumnDef(
          label: _tr('col_product'),
          flex: 1.5,
          cellBuilder: (r, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectableText(_value(r.product),
                  style: AppTextStyles.body))),
      TableColumnDef(
          label: _tr('col_store'),
          flex: 1.3,
          cellBuilder: (r, _) => TableCells.text(_value(r.store))),
      TableColumnDef(
          label: _tr('col_quantity_withdrawn'),
          cellBuilder: (r, _) => TableCells.text(_value(r.quantityWithdrawn))),
      TableColumnDef(
          label: _tr('col_new_quantity'),
          cellBuilder: (r, _) => TableCells.text(_value(r.newQuantity))),
      TableColumnDef(
          label: _tr('col_withdrawn_by'),
          cellBuilder: (r, _) => TableCells.text(_value(r.withdrawnBy))),
      TableColumnDef(
          label: _tr('col_date_time'),
          flex: 1.5,
          cellBuilder: (r, _) => TableCells.text(_value(r.createdAt))),
    ];

class ConsumedStocksCard extends StatelessWidget {
  const ConsumedStocksCard(
      {super.key, required this.row, required this.number});
  final ConsumedStockData row;
  final int number;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: '#$number  ${_value(row.product)}',
      subtitle: _value(row.store),
      body: InfoGrid(minColumnWidth: 130, maxColumns: 2, children: [
        InfoRow(
            label: _tr('qty_withdrawn_stat'),
            value: _value(row.quantityWithdrawn)),
        InfoRow(label: _tr('new_qty_stat'), value: _value(row.newQuantity)),
        InfoRow(
            label: _tr('withdrawn_by_stat'), value: _value(row.withdrawnBy)),
        InfoRow(label: _tr('col_date_time'), value: _value(row.createdAt)),
      ]));
}
