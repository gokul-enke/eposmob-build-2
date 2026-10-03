import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/filters/balance_filter.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../state/supplier_list_controller.dart';
import '../supplier_labels.dart';

/// The suppliers list filter panel: name, email, phone, balance.
FilterPanel supplierFilterPanel(SupplierListController controller) {
  return FilterPanel(
    key: const ValueKey('supplier-list-filters'),
    title: 'supplier_list.find'.tr,
    hint: 'supplier_list.find_hint'.tr,
    resetLabel: 'list.reset'.tr,
    onSearch: controller.scheduleSearch,
    onSubmit: controller.search,
    onReset: controller.reset,
    fields: [
      TextFilterField(
        controller: controller.nameController,
        label: 'suppliers.name'.tr,
        hint: 'suppliers.search_name'.tr,
        icon: Icons.person_outline_rounded,
        keyboardType: TextInputType.name,
      ),
      TextFilterField(
        controller: controller.emailController,
        label: 'suppliers.email'.tr,
        hint: 'suppliers.search_email'.tr,
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      TextFilterField(
        controller: controller.phoneController,
        label: 'suppliers.phone'.tr,
        hint: 'suppliers.search_phone'.tr,
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      DropdownFilterField<BalanceFilter>(
        label: 'suppliers.balance'.tr,
        icon: Icons.account_balance_wallet_outlined,
        value: controller.balance,
        onChanged: controller.setBalance,
        options: [
          for (final filter in BalanceFilter.values)
            FilterOption(filter, SupplierLabels.balanceFilter(filter)),
        ],
      ),
    ],
  );
}
