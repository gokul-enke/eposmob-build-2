import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/general_payment_entry.dart';

/// A required New Entry choice (category, account or payment method) in the
/// shared form style, opening the white searchable popup the list filters
/// use ([AppSearchDropdownPopup]). Disabled while its options load.
class GeneralPaymentPicker extends StatelessWidget {
  const GeneralPaymentPicker({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.loading = false,
  });

  /// Stays the same for the field's life: re-keying dropdown_search while
  /// its popup closes pops the route a second time.
  final Key fieldKey;
  final String label;
  final List<GeneralPaymentOption> options;

  /// The chosen option's id.
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    GeneralPaymentOption? selected;
    for (final option in options) {
      if (option.id == value) selected = option;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label: label, required: true),
        const SizedBox(height: AppSpacing.xs),
        DropdownSearch<GeneralPaymentOption>(
          key: fieldKey,
          enabled: !loading,
          items: (_, __) => options,
          selectedItem: selected,
          compareFn: (a, b) => a.id == b.id,
          itemAsString: (option) => option.label,
          decoratorProps:
              DropDownDecoratorProps(decoration: AppInputDecoration.of()),
          dropdownBuilder: (_, option) => Text(
              option?.label ??
                  (loading
                      ? 'general.loading'.tr
                      : 'general_payments.choose'.tr),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: option == null
                  ? AppTextStyles.input.copyWith(color: AppColors.hint)
                  : AppTextStyles.input),
          popupProps: AppSearchDropdownPopup.menu<GeneralPaymentOption>(
              searchHint: 'general.search'.tr,
              itemLabel: (option) => option.label),
          onChanged: (option) => onChanged(option?.id),
        ),
      ],
    );
  }
}
