import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../state/customer_transactions_controller.dart';

/// Reference / type / date-range filters with Reset and Apply.
///
/// Edits only change the controller's draft; Apply (or Enter in the
/// reference field) commits them and reloads.
class TransactionFilterPanel extends StatelessWidget {
  const TransactionFilterPanel({super.key, required this.controller});

  final CustomerTransactionsController controller;

  static String _formatRange(DateTimeRange range) =>
      '${CustomerTransactionsController.formatApiDate(range.start)} – '
      '${CustomerTransactionsController.formatApiDate(range.end)}';

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
              title: 'customer_transactions.tooltip_filter'.tr,
              resetLabel: 'customer_transactions.btn_reset'.tr,
              useSurface: false,
              onSearch: () {},
              onSubmit: controller.applyFilters,
              onReset: controller.resetFilters,
              fields: [
                TextFilterField(
                  controller: controller.referenceController,
                  label: 'customer_transactions.label_reference_number'.tr,
                  hint: 'customer_transactions.hint_reference'.tr,
                  icon: Icons.tag_rounded,
                ),
                DropdownFilterField<TransactionDirection?>(
                  label: 'customer_transactions.label_transaction_type'.tr,
                  hint: 'customer_transactions.hint_select_type'.tr,
                  icon: Icons.swap_vert_rounded,
                  value: controller.draftType,
                  onChanged: controller.setDraftType,
                  options: [
                    FilterOption(
                      null,
                      'customer_transactions.label_all_types'.tr,
                    ),
                    for (final type in TransactionDirection.values)
                      FilterOption(type, type.translationKey.tr),
                  ],
                ),
                DateRangeFilterField(
                  label: 'customer_profile.tx_date_range'.tr,
                  hint: 'customer_profile.tx_date_range_hint'.tr,
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
                label: 'customer_transactions.btn_apply_filters'.tr,
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
