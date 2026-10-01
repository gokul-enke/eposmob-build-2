import 'package:flutter/material.dart';

import '../form/app_input_decoration.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// One field of a [FilterPanel]. Each page declares its own list of fields;
/// the panel lays them out and styles them. Every field type is exactly
/// [AppSizes.control] tall (see [AppInputDecoration.filter]).
sealed class FilterFieldDef {
  const FilterFieldDef();

  /// Builds the input. Text inputs call [onTextChanged] on every edit and
  /// [onTextSubmitted] when the user confirms (Enter).
  Widget build(
    BuildContext context, {
    required VoidCallback onTextChanged,
    required VoidCallback onTextSubmitted,
  });
}

/// Free-text search field.
class TextFilterField extends FilterFieldDef {
  const TextFilterField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  @override
  Widget build(
    BuildContext context, {
    required VoidCallback onTextChanged,
    required VoidCallback onTextSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      onChanged: (_) => onTextChanged(),
      onFieldSubmitted: (_) => onTextSubmitted(),
      style: AppTextStyles.input,
      decoration:
          AppInputDecoration.filter(label: label, hint: hint, icon: icon),
    );
  }
}

/// Any widget as a filter field (a screen-specific picker, a custom
/// dropdown). Gets the panel's width and, unless [fixedHeight] is false,
/// the same [AppSizes.control] height as the other fields.
///
/// Prefer [TextFilterField] / [DropdownFilterField] /
/// [DateRangeFilterField]; use this when none of them fits. Style inner
/// inputs with [AppInputDecoration.filter] so they match.
class CustomFilterField extends FilterFieldDef {
  const CustomFilterField({required this.child, this.fixedHeight = true});

  final Widget child;
  final bool fixedHeight;

  @override
  Widget build(
    BuildContext context, {
    required VoidCallback onTextChanged,
    required VoidCallback onTextSubmitted,
  }) {
    if (!fixedHeight) return child;
    return SizedBox(height: AppSizes.control, child: child);
  }
}

/// One choice of a [DropdownFilterField].
@immutable
class FilterOption<T> {
  const FilterOption(this.value, this.label);

  final T value;
  final String label;
}

/// Single-choice dropdown. Reports changes through [onChanged]; the page
/// decides whether that triggers a search.
class DropdownFilterField<T> extends FilterFieldDef {
  const DropdownFilterField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final IconData icon;
  final T value;
  final List<FilterOption<T>> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(
    BuildContext context, {
    required VoidCallback onTextChanged,
    required VoidCallback onTextSubmitted,
  }) {
    return DropdownButtonFormField<T>(
      // Rebuild when the value is changed from outside (e.g. Reset).
      key: ValueKey<Object?>(value),
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration:
          AppInputDecoration.filter(label: label, hint: hint, icon: icon),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.control),
      style: AppTextStyles.themed(context, AppTextStyles.input),
      items: [
        for (final option in options)
          DropdownMenuItem<T>(value: option.value, child: Text(option.label)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Date-range picker field (reports, sales lists).
class DateRangeFilterField extends FilterFieldDef {
  const DateRangeFilterField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.formatRange,
    this.hint,
    this.icon = Icons.date_range_outlined,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final String? hint;
  final IconData icon;
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  /// Turns the selected range into display text.
  final String Function(DateTimeRange range) formatRange;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(
    BuildContext context, {
    required VoidCallback onTextChanged,
    required VoidCallback onTextSubmitted,
  }) {
    final current = value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: firstDate ?? DateTime(now.year - 10),
          lastDate: lastDate ?? DateTime(now.year + 1),
          initialDateRange: current,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        isEmpty: current == null,
        textAlignVertical: TextAlignVertical.center,
        decoration: AppInputDecoration.filter(
          label: label,
          hint: hint,
          icon: icon,
          suffix: current == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          current == null ? '' : formatRange(current),
          style: AppTextStyles.input,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
