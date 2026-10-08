import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';
import 'app_form_fields.dart';
import 'app_input_decoration.dart';

/// Shared popup styling for searchable listing filters. The package retains
/// ownership of selection and popup dismissal; this only supplies the UI tokens.
abstract final class AppSearchDropdownPopup {
  static PopupProps<T> menu<T>({
    required String searchHint,
    required String Function(T) itemLabel,
  }) =>
      PopupProps<T>.menu(
        showSearchBox: true,
        showSelectedItems: true,
        menuProps: const MenuProps(
          backgroundColor: AppColors.surface,
          surfaceTintColor: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        searchFieldProps: TextFieldProps(
          decoration:
              AppInputDecoration.of(hint: searchHint, icon: Icons.search),
          style: AppTextStyles.input,
          cursorColor: AppColors.primary,
        ),
        itemClickProps: const ClickProps(
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          hoverColor: AppColors.softBlue,
          focusColor: AppColors.softBlue,
          highlightColor: AppColors.softBlue,
          splashColor: AppColors.softBlue,
        ),
        itemBuilder: (context, item, disabled, selected) => Ink(
          color: selected ? AppColors.softBlue : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Text(
              itemLabel(item),
              style:
                  AppTextStyles.themed(context, AppTextStyles.input).copyWith(
                      color: disabled
                          ? AppColors.muted
                          : selected
                              ? AppColors.primary
                              : AppColors.heading),
            ),
          ),
        ),
      );
}

/// Dropdown whose text box filters the options as the user types, in the
/// shared form style. Use instead of [AppDropdownField] for long lists.
///
/// Shows a small spinner instead of the field while [loading].
class AppSearchDropdownField<T> extends StatelessWidget {
  const AppSearchDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.loading = false,
    this.required = false,
    this.menuHeight = 320,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool enabled;
  final bool loading;
  final bool required;
  final double menuHeight;

  @override
  Widget build(BuildContext context) {
    final selection = value != null && items.contains(value) ? value : null;
    final decoration = AppInputDecoration.of(hint: hint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label: label, required: required),
        const SizedBox(height: AppSpacing.xs),
        if (loading)
          Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.border),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
        else
          DropdownMenu<T>(
            // Rebuild when the selection or the options change so a value set
            // from code (autofill, reset) is shown.
            key: ValueKey<Object?>(Object.hash(selection, items.length)),
            initialSelection: selection,
            enabled: enabled && onChanged != null,
            enableFilter: true,
            requestFocusOnTap: true,
            expandedInsets: EdgeInsets.zero,
            menuHeight: menuHeight,
            textStyle: AppTextStyles.input,
            hintText: hint,
            inputDecorationTheme:
                Theme.of(context).inputDecorationTheme.copyWith(
                      hintStyle: decoration.hintStyle,
                      filled: decoration.filled,
                      fillColor: decoration.fillColor,
                      isDense: decoration.isDense,
                      contentPadding: decoration.contentPadding,
                      border: decoration.border,
                      enabledBorder: decoration.enabledBorder,
                      focusedBorder: decoration.focusedBorder,
                    ),
            onSelected: onChanged,
            dropdownMenuEntries: [
              for (final item in items)
                DropdownMenuEntry<T>(value: item, label: itemLabel(item)),
            ],
          ),
      ],
    );
  }
}
