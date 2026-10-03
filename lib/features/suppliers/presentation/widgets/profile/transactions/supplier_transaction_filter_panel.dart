import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../state/supplier_transactions_controller.dart';

/// Reference / type / date-range filters with Reset and Apply.
///
/// Edits only change the controller's draft; Apply (or Enter in the
/// reference field) commits them.
class SupplierTransactionFilterPanel extends StatelessWidget {
  const SupplierTransactionFilterPanel({super.key, required this.controller});

  final SupplierTransactionsController controller;

  static String _formatRange(DateTimeRange range) =>
      '${SupplierTransactionsController.formatApiDate(range.start)} – '
      '${SupplierTransactionsController.formatApiDate(range.end)}';

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FilterPanel(
              title: 'supplier_profile.trans_tooltip_filter'.tr,
              resetLabel: 'supplier_profile.trans_btn_reset'.tr,
              useSurface: false,
              onSearch: () {},
              onSubmit: controller.applyFilters,
              onReset: controller.resetFilters,
              fields: [
                TextFilterField(
                  controller: controller.referenceController,
                  label: 'supplier_profile.trans_label_reference_number'.tr,
                  hint: 'supplier_profile.trans_hint_reference'.tr,
                  icon: Icons.tag_rounded,
                ),
                DropdownFilterField<SupplierTransactionDirection?>(
                  label: 'supplier_profile.trans_label_type'.tr,
                  hint: 'supplier_profile.trans_hint_select_type'.tr,
                  icon: Icons.swap_vert_rounded,
                  value: controller.draftType,
                  onChanged: controller.setDraftType,
                  options: [
                    FilterOption(
                      null,
                      'supplier_profile.trans_label_all_types'.tr,
                    ),
                    for (final type in SupplierTransactionDirection.values)
                      FilterOption(type, type.translationKey.tr),
                  ],
                ),
                DateRangeFilterField(
                  label: 'supplier_profile.trans_label_date_range'.tr,
                  hint: 'supplier_profile.trans_hint_date_range'.tr,
                  value: controller.draftRange,
                  onChanged: controller.setDraftRange,
                  formatRange: _formatRange,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppPrimaryButton(
                label: 'supplier_profile.trans_btn_apply_filters'.tr,
                icon: Icons.check_rounded,
                onPressed: controller.applyFilters,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
