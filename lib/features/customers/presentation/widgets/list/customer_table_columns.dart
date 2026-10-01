import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../customer_avatar.dart';
import '../customer_labels.dart';

/// Columns of the customers table.
List<TableColumnDef<CustomerListModelData>> customerTableColumns({
  required ValueChanged<CustomerListModelData> onView,
}) {
  return [
    TableColumnDef(
      label: 'customers.col_no'.tr,
      flex: 0.55,
      align: TextAlign.center,
      cellBuilder: (_, number) => TableCells.number(number),
    ),
    TableColumnDef(
      label: 'customers.col_customer'.tr,
      flex: 2.3,
      cellBuilder: (customer, _) => TableCells.avatarName(
        name: CustomerLabels.name(customer.name),
        avatar: CustomerAvatar(name: customer.name, size: 36),
      ),
    ),
    TableColumnDef(
      label: 'customers.col_balance'.tr,
      flex: 1.25,
      cellBuilder: (customer, _) => TableCells.amount(customer.balance ?? 0),
    ),
    TableColumnDef(
      label: 'customers.col_phone'.tr,
      flex: 1.55,
      cellBuilder: (customer, _) => TableCells.text(
        customer.phone?.isNotEmpty == true ? customer.phone! : '—',
      ),
    ),
    TableColumnDef(
      label: 'customers.col_type'.tr,
      flex: 1.2,
      cellBuilder: (customer, _) =>
          TableCells.widget(CustomerTypeBadge(type: customer.customerType)),
    ),
    TableColumnDef(
      label: 'customers.col_action'.tr,
      flex: 1.15,
      cellBuilder: (customer, _) => TableCells.action(
        label: 'customers.view'.tr,
        icon: Icons.visibility,
        onPressed: () => onView(customer),
      ),
    ),
  ];
}
