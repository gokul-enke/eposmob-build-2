import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/supplier.dart';
import '../supplier_labels.dart';

/// Columns of the suppliers table.
List<TableColumnDef<Supplier>> supplierTableColumns({
  required ValueChanged<Supplier> onView,
}) {
  return [
    TableColumnDef(
      label: 'suppliers.number'.tr,
      flex: 0.5,
      align: TextAlign.center,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef(
      label: 'suppliers.name'.tr,
      flex: 2.2,
      cellBuilder: (supplier, _) => TableCells.avatarName(
        name: SupplierLabels.orDash(supplier.name),
        avatar: AppAvatar(
          name: supplier.name,
          semanticLabel: supplier.name,
          size: 36,
        ),
      ),
    ),
    TableColumnDef(
      label: 'suppliers.email'.tr,
      flex: 1.7,
      cellBuilder: (supplier, _) =>
          TableCells.text(SupplierLabels.orDash(supplier.email)),
    ),
    TableColumnDef(
      label: 'suppliers.phone'.tr,
      flex: 1.3,
      cellBuilder: (supplier, _) =>
          TableCells.text(SupplierLabels.orDash(supplier.phone)),
    ),
    TableColumnDef(
      label: 'suppliers.address'.tr,
      flex: 1.4,
      cellBuilder: (supplier, _) =>
          TableCells.text(SupplierLabels.orDash(supplier.address)),
    ),
    TableColumnDef(
      label: 'suppliers.current_balance'.tr,
      flex: 1.3,
      cellBuilder: (supplier, _) => TableCells.amount(supplier.currentBalance),
    ),
    TableColumnDef(
      label: 'suppliers.action'.tr,
      flex: 1.1,
      cellBuilder: (supplier, _) => TableCells.action(
        label: 'list.view'.tr,
        icon: Icons.visibility_outlined,
        onPressed: () => onView(supplier),
      ),
    ),
  ];
}
