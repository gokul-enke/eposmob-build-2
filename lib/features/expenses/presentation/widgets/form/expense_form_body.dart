import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import '../../state/expense_form_controller.dart';
import 'expense_form_inputs.dart';

class ExpenseFormBody extends StatelessWidget with ExpenseFormInputs {
  const ExpenseFormBody(
      {super.key,
      required this.controller,
      required this.formKey,
      required this.currency,
      required this.categoryOptions,
      required this.debitAccountOptions,
      required this.creditAccountOptions,
      required this.paymentMethodOptions,
      required this.allowedPaymentMethods,
      required this.onSubmit,
      required this.onCancel,
      required this.onError});
  @override
  final ExpenseFormController controller;
  final GlobalKey<FormState> formKey;
  @override
  final String currency;
  final List<Map<String, dynamic>> categoryOptions,
      debitAccountOptions,
      creditAccountOptions,
      paymentMethodOptions;
  final List<String> Function(Map<String, dynamic>?) allowedPaymentMethods;
  final ValueChanged<bool> onSubmit;
  final VoidCallback onCancel;
  @override
  final ValueChanged<String> onError;
  bool _isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final isPhone = _isPhone(context);

    return SafeArea(
      child: CustomBoxShadowContainer(
        margin: EdgeInsets.symmetric(
          horizontal: isPhone ? 4 : 10,
          vertical: isPhone ? 8 : 20,
        ),
        padding: EdgeInsets.all(isPhone ? 14 : 20),
        circleRadius: 22,
        offsetValue: const Offset(1, 1),
        blurRadius: 6,
        color: Colors.white,
        child: Form(
          key: formKey,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: ListView(
              children: [
                buildHeader(),
                const SizedBox(height: 20),
                buildSectionTitle('expense.section_entry_details'.tr),
                const SizedBox(height: 15),
                buildFormFields(isPhone),
                const SizedBox(height: 15),
                buildLabel('expense.label_notes'.tr),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(8),
                  child: buildNotesField(controller.notesFocus),
                ),
                const SizedBox(height: 30),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(9),
                  child: buildActionButtons(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFormFields(bool isPhone) {
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('expense.reference_no'.tr),
        buildDisabledTextField(controller.referenceNo),
        const SizedBox(height: 15),
        buildLabel('expense.label_expense_category'.tr, isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_category_dropdown'),
            focusNode: controller.categoryFocus,
            hint: 'expense.hint_select_option'.tr,
            value: controller.selectedCategory,
            items: categoryOptions,
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) =>
                controller.update(() => controller.selectedCategory = val),
          ),
        ),
        const SizedBox(height: 15),
        buildLabel('expense.label_expense_account_debit'.tr, isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(4),
          child: buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_debit_account_dropdown'),
            focusNode: controller.debitAccountFocus,
            hint: 'expense.hint_select_option'.tr,
            value: controller.selectedDebitAccount,
            items: debitAccountOptions,
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) =>
                controller.update(() => controller.selectedDebitAccount = val),
          ),
        ),
        const SizedBox(height: 15),
        buildLabel('expense.amount'.tr, isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(6),
          child: buildAmountField(controller.amountFocus),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel('expense.label_payment_date'.tr, isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: buildDatePickerField(controller.dateFocus),
        ),
        const SizedBox(height: 15),
        buildLabel('expense.label_description_vendor_create'.tr),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: buildTextField(
            controller: controller.descriptionController,
            hint: 'expense.hint_description'.tr,
            focusNode: controller.descriptionFocus,
          ),
        ),
        const SizedBox(height: 15),
        buildLabel('expense.label_paid_from'.tr, isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(5),
          child: buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_credit_account_dropdown'),
            focusNode: controller.creditAccountFocus,
            hint: 'expense.hint_select_option'.tr,
            value: controller.selectedCreditAccount,
            items: creditAccountOptions,
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) =>
                controller.selectCreditAccount(val, allowedPaymentMethods(val)),
          ),
        ),
        const SizedBox(height: 15),
        buildLabel('expense.payment_method'.tr, isRequired: true),
        FocusTraversalOrder(
          order: const NumericFocusOrder(7),
          child: buildDropdownField<Map<String, dynamic>>(
            key: const ValueKey('expense_payment_method_dropdown'),
            focusNode: controller.paymentMethodFocus,
            hint: 'expense.hint_select_option'.tr,
            value: controller.selectedPaymentMethod,
            items: controller.filteredPaymentMethods(paymentMethodOptions),
            displayText: (item) => item['name'] ?? '',
            onChanged: (val) =>
                controller.update(() => controller.selectedPaymentMethod = val),
          ),
        ),
      ],
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftColumn,
          const SizedBox(height: 15),
          rightColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leftColumn),
        const SizedBox(width: 30),
        Expanded(child: rightColumn),
      ],
    );
  }

  Widget buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomBackButton(
          onPressed: () {
            onCancel();
          },
          text: 'expense.all_expenses'.tr,
        ),
        Text(
          'expense.create_title'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            InkWell(
              onTap: () {
                onCancel();
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'expense.title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
            Text(
              'expense.breadcrumb_create'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                ColorManager.kPrimaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildActionButtons(BuildContext context) {
    final isPhone = _isPhone(context);

    final createButton = CustomRoundButtonAdvanced(
      title: 'expense.btn_create'.tr,
      fct: () => onSubmit(false),
      width: isPhone ? double.infinity : 100,
      height: 40,
      fontSize: 12,
      radius: 5,
      isLoading: controller.isSubmitting,
      focusNode: controller.createBtnFocus,
    );

    final createAnotherButton = CustomRoundButtonAdvanced(
      title: 'expense.btn_create_another'.tr,
      fct: () => onSubmit(true),
      width: isPhone ? double.infinity : 170,
      height: 40,
      fontSize: 12,
      radius: 5,
      boxColor: Colors.white,
      textColor: ColorManager.textColor,
      borderColor: Colors.grey.shade300,
      isLoading: controller.isSubmitting,
      focusNode: controller.createAnotherBtnFocus,
    );

    final cancelButton = CustomRoundButtonAdvanced(
      title: 'expense.btn_cancel'.tr,
      fct: () {
        onCancel();
      },
      width: isPhone ? double.infinity : 100,
      height: 40,
      fontSize: 12,
      radius: 5,
      boxColor: Colors.transparent,
      textColor: ColorManager.textColor,
      borderColor: Colors.transparent,
      focusNode: controller.cancelBtnFocus,
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          createButton,
          const SizedBox(height: 10),
          createAnotherButton,
          const SizedBox(height: 10),
          cancelButton,
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        createButton,
        createAnotherButton,
        cancelButton,
      ],
    );
  }
}
