import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'fulfillment_form_values.dart';
import 'packing_photo_thumbnail.dart';

Widget fulfillmentDropdown<T>({
  required String label,
  required T? value,
  required List<T> items,
  required String Function(T) itemLabel,
  required ValueChanged<T?> onChanged,
  bool required = false,
  bool enabled = true,
}) =>
    FulfillmentLabeledField(
      label: label,
      required: required,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _fieldDecoration(),
        child: DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: label,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child:
                        Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: !enabled || items.isEmpty ? null : onChanged,
          validator: required
              ? (selected) => selected == null
                  ? 'sales_order_details.msg_required_field'.tr
                  : null
              : null,
        ),
      ),
    );

Widget fulfillmentTextField({
  required TextEditingController controller,
  required String label,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  int maxLines = 1,
  bool required = false,
}) =>
    FulfillmentLabeledField(
      label: label,
      required: required,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ??
            (required
                ? (value) => (value == null || value.trim().isEmpty)
                    ? 'sales_order_details.msg_required_field'.tr
                    : null
                : null),
        decoration: _textFieldDecoration(label),
      ),
    );

Widget fulfillmentDateField({
  required TextEditingController controller,
  required String label,
  required VoidCallback onTap,
  bool required = false,
}) =>
    FulfillmentLabeledField(
      label: label,
      required: required,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        validator: required
            ? (value) => (value == null || value.trim().isEmpty)
                ? 'sales_order_details.msg_required_field'.tr
                : null
            : null,
        decoration: _textFieldDecoration(label).copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
      ),
    );

class FulfillmentLabeledField extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;

  const FulfillmentLabeledField({
    required this.label,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s13,
                0.27,
                ColorManager.textColor,
              ),
              children: [
                TextSpan(text: label),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
}

BoxDecoration _fieldDecoration() => BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    );

InputDecoration _textFieldDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorManager.kPrimaryColor),
      ),
    );

Widget fulfillmentFilePickerCard({
  required String title,
  required String buttonLabel,
  required IconData icon,
  required VoidCallback onPick,
  required List<PlatformFile> files,
  required ValueChanged<int> onRemove,
  bool showImagePreviews = false,
}) =>
    Builder(
      builder: (context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              CustomRoundButton(
                title: buttonLabel,
                fct: onPick,
                height: 38,
                width: 160,
                fontSize: FontSize.s11,
                boxColor: Colors.white,
                borderColor: ColorManager.kPrimaryColor,
                textColor: ColorManager.kPrimaryColor,
                icon: Icon(icon, color: ColorManager.kPrimaryColor, size: 17),
              ),
              if (files.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...files.asMap().entries.map(
                      (entry) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: showImagePreviews
                            ? LocalPackingPhotoThumbnail(file: entry.value)
                            : null,
                        title: Text(entry.value.name),
                        subtitle: Text(fulfillmentFileSize(entry.value.size)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => onRemove(entry.key),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
