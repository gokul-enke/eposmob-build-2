import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SupplierReportHeader extends StatelessWidget {
  const SupplierReportHeader(
      {super.key,
      required this.showFilters,
      required this.hasActiveFilters,
      required this.activeFiltersListenable,
      required this.activeFiltersBuilder,
      required this.onToggle});
  final bool showFilters, hasActiveFilters;
  final Listenable activeFiltersListenable;
  final bool Function() activeFiltersBuilder;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'supplier_transaction_report.title'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
        ),
        _buildFilterToggleButton(),
      ],
    );
  }

  Widget _buildFilterToggleButton() {
    return FilterToggleButton(
      key: const ValueKey('supplier-transactions-report-filter-toggle'),
      showFilters: showFilters,
      hasActiveFilters: hasActiveFilters,
      activeFiltersListenable: activeFiltersListenable,
      activeFiltersBuilder: activeFiltersBuilder,
      onPressed: onToggle,
      showTooltip: 'supplier_transaction_report.filters'.tr,
      hideTooltip: 'supplier_transaction_report.hide'.tr,
    );
  }
}
