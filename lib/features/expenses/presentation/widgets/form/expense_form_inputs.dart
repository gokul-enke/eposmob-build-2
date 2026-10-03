import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../../state/expense_form_controller.dart';

mixin ExpenseFormInputs on StatelessWidget {
  ExpenseFormController get controller;
  String get currency;
  ValueChanged<String> get onError;
  Widget buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade300, thickness: 0.8),
      ],
    );
  }

  Widget buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          text: text.replaceAll('*', ''),
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.1,
            ColorManager.textColor,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: " *",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildDisabledTextField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeightManager.medium,
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String hint,
    required FocusNode focusNode,
  }) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;
        return BuildBoxShadowContainer(
          height: 42,
          circleRadius: 6,
          border: hasFocus
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
              : Border.all(color: Colors.grey.shade300),
          showShadow: !hasFocus,
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }

  Widget buildDatePickerField(FocusNode focusNode) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return SizedBox(
      height: 42,
      child: CalendarPickerTableCell(
        focusNode: focusNode,
        initialDate: controller.selectedDate,
        firstDate: DateTime(2000),
        lastDate: today,
        onDateSelected: (DateTime date) {
          if (date.isAfter(today)) {
            onError('expense.error_future_date'.tr);
            return;
          }
          controller.update(() {
            controller.selectedDate = date;
          });
        },
      ),
    );
  }

  Widget buildDropdownField<T>({
    Key? key,
    FocusNode? focusNode,
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required Function(T?) onChanged,
  }) {
    return CustomDropDownWithSearch<T>(
      key: key,
      focusNode: focusNode,
      hintText: hint,
      value: value,
      items: items,
      onChanged: onChanged,
      displayText: displayText,
      showName: false,
      height: 42,
      autofocus: false,
    );
  }

  Widget buildAmountField(FocusNode focusNode) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;

        return BuildBoxShadowContainer(
          height: 42,
          circleRadius: 6,
          border: hasFocus
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
              : Border.all(color: Colors.grey.shade300),
          showShadow: !hasFocus,
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
          child: TextFormField(
            controller: controller.amountController,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'expense.error_amount_required'.tr;
              }
              if (double.tryParse(val) == null) {
                return 'expense.error_amount_invalid'.tr;
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'expense.hint_amount'.tr,
              prefixIcon: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Text(
                  currency,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.1,
                    Colors.grey.shade600,
                  ),
                ),
              ),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }

  Widget buildNotesField(FocusNode focusNode) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;
        return BuildBoxShadowContainer(
          circleRadius: 6,
          border: hasFocus
              ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
              : Border.all(color: Colors.grey.shade300),
          showShadow: !hasFocus,
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
          child: TextFormField(
            controller: controller.notesController,
            focusNode: focusNode,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'expense.hint_notes'.tr,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        );
      },
    );
  }
}
