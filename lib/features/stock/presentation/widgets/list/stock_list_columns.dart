import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'stock_list_cells.dart';

List<TableColumnDef<ListStockModelData>> stockListColumns(
        {required bool canViewPurchasePrice,
        required bool variantEnabled,
        required Widget Function(ListStockModelData) actions,
        required void Function(ListStockModelData) onCopy}) =>
    [
      TableColumnDef(
          label: 'stock.col_product'.tr,
          flex: 1.8,
          cellBuilder: (s, _) => TableCells.widget(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.productName ?? 'stock.unnamed'.tr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.input),
                    if (variantEnabled && s.productVariantId != null)
                      Text(stockVariant(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption),
                  ]))),
      TableColumnDef(
          label: 'stock.barcode'.tr,
          flex: 1.6,
          cellBuilder: (s, _) =>
              TableCells.widget(stockBarcode(s, () => onCopy(s)))),
      TableColumnDef(
          label: 'stock.retail_price'.tr,
          cellBuilder: (s, _) =>
              TableCells.text(s.retailPrice ?? 'stock.na'.tr)),
      TableColumnDef(
          label: 'stock.mrp'.tr,
          cellBuilder: (s, _) => TableCells.text(s.mrp ?? 'stock.na'.tr)),
      if (canViewPurchasePrice)
        TableColumnDef(
            label: 'stock.purchase_price'.tr,
            cellBuilder: (s, _) =>
                TableCells.text(s.purchaseRate ?? 'stock.na'.tr)),
      TableColumnDef(
          label: 'stock.quantity'.tr,
          flex: .8,
          cellBuilder: (s, _) => TableCells.widget(stockQuantity(s))),
      TableColumnDef(
          label: 'stock.unit'.tr,
          flex: .6,
          cellBuilder: (s, _) => TableCells.text(s.unit ?? 'stock.na'.tr)),
      TableColumnDef(
          label: 'stock.rack'.tr,
          flex: .7,
          cellBuilder: (s, _) => TableCells.text(s.rack ?? 'stock.na'.tr)),
      TableColumnDef(
          label: 'stock.order_date'.tr,
          flex: 1.1,
          cellBuilder: (s, _) =>
              TableCells.text(DateHelper.formatISODate(s.orderDate ?? ''))),
      TableColumnDef(
          label: 'stock.action'.tr,
          flex: 2.4,
          cellBuilder: (s, _) => TableCells.widget(actions(s))),
    ];
