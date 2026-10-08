import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/get_product.dart';
import 'product_list_actions.dart';
import 'product_list_copy.dart';
import 'product_list_labels.dart';

List<TableColumnDef<GetProduct>> productListColumns({
  required bool itemCodeEnabled,
  required bool canViewPurchasePrice,
  required ValueChanged<GetProduct> onView,
  required ValueChanged<GetProduct> onDelete,
  required bool deleting,
}) =>
    [
      TableColumnDef(
          label: 'product.col_no'.tr,
          flex: .5,
          cellBuilder: (_, number) => TableCells.number(number)),
      TableColumnDef(
          label: 'product.product_name'.tr,
          flex: 2,
          cellBuilder: (p, _) => TableCells.text(ProductListLabels.name(p))),
      if (itemCodeEnabled)
        TableColumnDef(
            label: 'product.item_code'.tr,
            flex: 1.2,
            cellBuilder: (p, _) => TableCells.widget(ProductListCopy(
                value: p.itemCode, message: 'product.item_code_copied'))),
      TableColumnDef(
          label: 'product.category_name'.tr,
          flex: 1.3,
          cellBuilder: (p, _) =>
              TableCells.text(ProductListLabels.category(p))),
      TableColumnDef(
          label: 'product.price'.tr,
          cellBuilder: (p, _) =>
              TableCells.text(ProductListLabels.value(p.price?.price))),
      TableColumnDef(
          label: 'product.mrp'.tr,
          cellBuilder: (p, _) =>
              TableCells.text(ProductListLabels.value(p.mrp))),
      if (canViewPurchasePrice)
        TableColumnDef(
            label: 'product.purchase_price'.tr,
            cellBuilder: (p, _) => TableCells.text(
                ProductListLabels.value(ProductListLabels.purchasePrice(p)))),
      TableColumnDef(
          label: 'product.unit'.tr,
          flex: .7,
          cellBuilder: (p, _) =>
              TableCells.text(ProductListLabels.value(p.unit))),
      TableColumnDef(
          label: 'product.barcode'.tr,
          flex: 1.7,
          cellBuilder: (p, _) => TableCells.widget(ProductListCopy(
              value: p.barcode, message: 'product.barcode_copied'))),
      TableColumnDef(
          label: 'product.action'.tr,
          flex: 2.5,
          cellBuilder: (p, _) => TableCells.widget(ProductListActions(
              onView: () => onView(p),
              onDelete:
                  deleting || p.productId == null ? null : () => onDelete(p)))),
    ];
