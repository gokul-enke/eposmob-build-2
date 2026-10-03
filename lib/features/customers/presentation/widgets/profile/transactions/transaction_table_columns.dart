import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/customer_list.dart';
import 'transaction_labels.dart';

/// Columns of the transactions table (wide layout).
List<TableColumnDef<CustomerTransaction>> transactionTableColumns({
  required ValueChanged<CustomerTransaction> onView,
}) {
  return [
    TableColumnDef(
      label: 'customers.col_no'.tr,
      flex: 0.5,
      align: TextAlign.center,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef(
      label: 'customer_profile.col_reference'.tr,
      flex: 1.8,
      cellBuilder: (transaction, _) => TableCells.avatarName(
        name: TransactionLabels.reference(transaction),
        avatar: TransactionTypeIcon(type: transaction.type, size: 32),
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_date'.tr,
      flex: 1.1,
      cellBuilder: (transaction, _) =>
          TableCells.text(TransactionLabels.date(transaction)),
    ),
    TableColumnDef(
      label: 'customer_profile.col_type'.tr,
      flex: 0.9,
      cellBuilder: (transaction, _) =>
          TableCells.text(TransactionLabels.orNa(transaction.type)),
    ),
    TableColumnDef(
      label: 'customer_profile.col_payment_method'.tr,
      flex: 1.2,
      cellBuilder: (transaction, _) =>
          TableCells.text(TransactionLabels.orNa(transaction.paymentMethod)),
    ),
    TableColumnDef(
      label: 'customer_profile.col_amount'.tr,
      flex: 1.2,
      cellBuilder: (transaction, _) => TableCells.text(
        TransactionLabels.amount(transaction),
        color: TransactionLabels.amountColor(transaction),
        weight: FontWeight.w700,
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_status'.tr,
      flex: 1,
      cellBuilder: (transaction, _) => TableCells.widget(
        TransactionStatusBadge(status: transaction.status),
      ),
    ),
    TableColumnDef(
      label: 'customer_profile.col_action'.tr,
      flex: 1,
      cellBuilder: (transaction, _) => TableCells.action(
        label: 'customers.view'.tr,
        icon: Icons.visibility_outlined,
        onPressed: () => onView(transaction),
      ),
    ),
  ];
}
