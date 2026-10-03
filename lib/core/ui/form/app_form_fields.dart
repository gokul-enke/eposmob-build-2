import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';
import 'app_input_decoration.dart';

/// Text input in the shared form style. Shows a red `*` after [label] when
/// [required] is true.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.required = false,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.suffix,
    this.autovalidateMode,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool required;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final Widget? suffix;
  final AutovalidateMode? autovalidateMode;

  /// Key for the inner [TextFormField] (tests, focus traversal).
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label: label, required: required),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          autovalidateMode: autovalidateMode,
          style: AppTextStyles.input,
          decoration: AppInputDecoration.of(
            hint: hint,
            icon: icon,
            suffix: suffix,
          ),
        ),
      ],
    );
  }
}

/// Dropdown in the shared form style.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.icon,
    this.required = false,
    this.validator,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final IconData? icon;
  final bool required;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label: label, required: required),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          key: ValueKey<Object?>(value),
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          validator: validator,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          style: AppTextStyles.themed(context, AppTextStyles.input),
          decoration: AppInputDecoration.of(hint: hint, icon: icon),
        ),
      ],
    );
  }
}

/// Small bold label above a form input.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.red),
            ),
        ],
      ),
      style: const TextStyle(
        color: AppColors.body,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Lays form fields out in equal columns: 1 below [twoColumnsFrom], 2 below
/// [threeColumnsFrom], otherwise [maxColumns] (default 3).
class ResponsiveFieldGrid extends StatelessWidget {
  const ResponsiveFieldGrid({
    super.key,
    required this.children,
    this.maxColumns = 3,
    this.twoColumnsFrom = 520,
    this.threeColumnsFrom = 860,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final int maxColumns;
  final double twoColumnsFrom;
  final double threeColumnsFrom;
  final double spacing;
  final double runSpacing;

  int columnsFor(double width) {
    if (width < twoColumnsFrom) return 1;
    if (width < threeColumnsFrom) return 2.clamp(1, maxColumns);
    return maxColumns;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
