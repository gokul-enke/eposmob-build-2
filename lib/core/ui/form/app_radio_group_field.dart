import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';
import 'app_form_fields.dart';

/// A labelled row of radio options in the shared form style (same border and
/// height as [AppTextField]). Options wrap onto new lines on narrow widths.
class AppRadioGroupField<T> extends StatelessWidget {
  const AppRadioGroupField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.required = false,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T option) optionLabel;
  final ValueChanged<T>? onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label: label, required: required),
        const SizedBox(height: AppSpacing.xs),
        Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.border),
          ),
          child: RadioGroup<T>(
            groupValue: value,
            onChanged: (selected) {
              if (selected != null) change?.call(selected);
            },
            child: Wrap(
              spacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final option in options)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    onTap: change == null ? null : () => change(option),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<T>(
                          value: option,
                          enabled: change != null,
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.xs,
                          ),
                          child: Text(
                            optionLabel(option),
                            style: AppTextStyles.input,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
