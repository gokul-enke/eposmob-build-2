import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/balance_filter.dart';
import '../../state/customer_list_controller.dart';

/// The customers list filter panel: name, email, phone, balance.
FilterPanel customerFilterPanel(CustomerListController controller) {
  return FilterPanel(
    title: 'customers.find'.tr,
    hint: 'customers.find_hint'.tr,
    resetLabel: 'customers.reset'.tr,
    embeddedResetLabel: 'customers.reset_filters'.tr,
    onSearch: controller.scheduleSearch,
    onSubmit: controller.search,
    onReset: controller.reset,
    fields: [
      TextFilterField(
        controller: controller.nameController,
        label: 'customers.name'.tr,
        hint: 'customers.search_name'.tr,
        icon: Icons.person_outline_rounded,
        keyboardType: TextInputType.name,
      ),
      TextFilterField(
        controller: controller.emailController,
        label: 'customers.email'.tr,
        hint: 'customers.search_email'.tr,
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      TextFilterField(
        controller: controller.phoneController,
        label: 'customers.phone'.tr,
        hint: 'customers.search_phone'.tr,
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      DropdownFilterField<BalanceFilter>(
        label: 'customers.balance'.tr,
        hint: 'customers.all_balances'.tr,
        icon: Icons.account_balance_wallet_outlined,
        value: controller.balance,
        onChanged: controller.setBalance,
        options: [
          for (final filter in BalanceFilter.values)
            FilterOption(filter, filter.translationKey.tr),
        ],
      ),
    ],
  );
}

/// Texts of the mobile collapsible filter tile.
CollapsedFilterTexts customerMobileFilterTexts() => CollapsedFilterTexts(
      title: 'customers.filters_title'.tr,
      collapsedSubtitle: 'customers.filters_summary'.tr,
      expandedSubtitle: 'customers.filters_hide'.tr,
    );
