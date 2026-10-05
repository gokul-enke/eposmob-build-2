import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';

import '../../state/sales_list_controller.dart';

class SalesFilterToggle extends StatelessWidget {
  const SalesFilterToggle(
      {super.key,
      required this.controller,
      required this.showFilters,
      required this.onToggle});
  final SalesListController controller;
  final bool showFilters;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return FilterToggleButton(
      key: const ValueKey('orders-list-filter-toggle'),
      showFilters: showFilters,
      hasActiveFilters: controller.hasActiveFilters,
      activeFiltersListenable: Listenable.merge([
        controller.orderNumberController,
        controller.customerNameController,
        controller.amountController,
        controller.emailController,
        controller.phoneController,
        controller.storeController,
        controller.statusController,
        controller.fromDateController,
        controller.toDateController,
      ]),
      activeFiltersBuilder: () => controller.hasActiveFilters,
      onPressed: onToggle,
      showTooltip: 'sales.show_filters'.tr,
      hideTooltip: 'sales.hide_filters'.tr,
    );
  }
}
