import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_purchase_labels.dart';

/// Columns of the purchase orders table (wide layout).
List<TableColumnDef<SupplierPurchase>> supplierPurchaseTableColumns({
  required String currency,
  required ValueChanged<SupplierPurchase> onView,
}) {
  return [
    TableColumnDef(
      label: 'suppliers.number'.tr,
      flex: 0.5,
      align: TextAlign.center,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef(
      label: 'supplier_profile.orders_label_purchase_number'.tr,
      flex: 1.8,
      cellBuilder: (purchase, _) => TableCells.avatarName(
        name: SupplierPurchaseLabels.orNa(purchase.purchaseNumber),
        avatar: SupplierPurchaseStatusIcon(status: purchase.status, size: 32),
      ),
    ),
    TableColumnDef(
      label: 'supplier_profile.col_items'.tr,
      flex: 0.8,
      cellBuilder: (purchase, _) => TableCells.text('${purchase.items.length}'),
    ),
    TableColumnDef(
      label: 'supplier_profile.orders_label_total'.tr,
      flex: 1.3,
      cellBuilder: (purchase, _) => TableCells.text(
        SupplierPurchaseLabels.money(currency, purchase.amountTotal),
        color: AppColors.green,
        weight: FontWeight.w700,
      ),
    ),
    TableColumnDef(
      label: 'supplier_profile.orders_label_status'.tr,
      flex: 1,
      cellBuilder: (purchase, _) => TableCells.widget(
        SupplierPurchaseStatusBadge(status: purchase.status),
      ),
    ),
    TableColumnDef(
      label: 'suppliers.action'.tr,
      flex: 1,
      cellBuilder: (purchase, _) => TableCells.action(
        label: 'list.view'.tr,
        icon: Icons.visibility_outlined,
        onPressed: () => onView(purchase),
      ),
    ),
  ];
}
