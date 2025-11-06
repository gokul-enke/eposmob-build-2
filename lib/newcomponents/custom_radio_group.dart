import 'package:flutter/material.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'custom_container_box.dart';

/// A reusable radio group component that displays a set of radio button options.
/// Supports generic types for flexibility and includes consistent styling with the app theme.
///
/// Usage Example:
/// ```dart
/// CustomRadioGroup<String>(
///   title: "Customer Type",
///   value: selectedCustomerType,
///   options: const ['B2C', 'B2B'],
///   onChanged: (String? newValue) {
///     setState(() {
///       selectedCustomerType = newValue ?? 'B2C';
///     });
///   },
///   displayText: (String value) => value,
///   isRequired: true,
/// )
/// ```
class CustomRadioGroup<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> options;
  final ValueChanged<T?> onChanged;
  final String Function(T) displayText;
  final bool isRequired;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final double? width;

  const CustomRadioGroup({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.displayText,
    this.isRequired = false,
    this.height,
    this.margin,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    Colors.red,
                  ),
                ),
            ],
          ),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: margin ?? const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: height ?? size.height * .048,
          width: width ?? size.width,
          child: Row(
            children: options.map((option) {
              return Row(
                children: [
                  Radio<T>(
                    value: option,
                    groupValue: value,
                    activeColor: ColorManager.kPrimaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                    onChanged: onChanged,
                  ),
                  Text(
                    displayText(option),
                    style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0.27,
                        ColorManager.textColor.withOpacity(.7)),
                  ),
                  if (option != options.last) const SizedBox(width: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
