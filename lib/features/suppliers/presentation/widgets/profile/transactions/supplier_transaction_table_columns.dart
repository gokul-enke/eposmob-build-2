import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_transaction_labels.dart';

/// Columns of the supplier transactions table (wide layout).
List<TableColumnDef<SupplierTransaction>> supplierTransactionTableColumns({
  required ValueChanged<SupplierTransaction> onView,
}) {
  return [
    TableColumnDef(
      label: 'suppliers.number'.tr,
      flex: 0.5,
      align: TextAlign.center,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef(
      label: 'supplier_profile.trans_label_reference_number'.tr,
      flex: 1.8,
      cellBuilder: (transaction, _) => TableCells.avatarName(
        name: SupplierTransactionLabels.reference(transaction),
        avatar: SupplierTransactionTypeIcon(type: transaction.type, size: 32),
      ),
    ),
    TableColumnDef(
      label: 'supplier_profile.trans_detail_date'.tr,
      flex: 1.1,
      cellBuilder: (transaction, _) =>
          TableCells.text(SupplierTransactionLabels.orNa(transaction.date)),
    ),
    TableColumnDef(
      label: 'supplier_profile.trans_detail_type'.tr,
      flex: 1.1,
      cellBuilder: (transaction, _) => TableCells.text(
        SupplierTransactionLabels.orNa(transaction.transactionType),
      ),
    ),
    TableColumnDef(
      label: 'supplier_profile.col_amount'.tr,
      flex: 1.2,
      cellBuilder: (transaction, _) => TableCells.text(
        SupplierTransactionLabels.amount(transaction),
        color: SupplierTransactionLabels.amountColor(transaction),
        weight: FontWeight.w700,
      ),
    ),
    TableColumnDef(
      label: 'general.status'.tr,
      flex: 1,
      cellBuilder: (transaction, _) => TableCells.widget(
        SupplierTransactionStatusBadge(status: transaction.status),
      ),
    ),
    TableColumnDef(
      label: 'suppliers.action'.tr,
      flex: 1,
      cellBuilder: (transaction, _) => TableCells.action(
        label: 'list.view'.tr,
        icon: Icons.visibility_outlined,
        onPressed: () => onView(transaction),
      ),
    ),
  ];
}
