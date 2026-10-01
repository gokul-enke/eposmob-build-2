import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/phone_number_formatter.dart';

import '../../../domain/customer_display.dart';
import '../../state/customer_form_controller.dart';

/// Name, contact, gender and date of birth.
class CustomerDetailsSection extends StatelessWidget {
  const CustomerDetailsSection({
    super.key,
    required this.form,
    required this.onPickDateOfBirth,
    this.firstNameFocus,
  });

  final CustomerFormController form;
  final VoidCallback onPickDateOfBirth;
  final FocusNode? firstNameFocus;

  @override
  Widget build(BuildContext context) {
    final genders = [
      ...CustomerGenders.values,
      // Keep a stored value the list doesn't know so it isn't lost.
      if (form.gender != null && !CustomerGenders.values.contains(form.gender))
        form.gender!,
    ];
    return SectionCard(
      title: 'customers.form.section_details'.tr,
      icon: Icons.person_outline,
      child: ResponsiveFieldGrid(
        children: [
          AppTextField(
            controller: form.firstName,
            fieldKey: const ValueKey('customer-form-first-name'),
            focusNode: firstNameFocus,
            label: 'add_customer.label_first_name'.tr,
            required: form.isEdit,
            validator: form.validateFirstName,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.lastName,
            fieldKey: const ValueKey('customer-form-last-name'),
            label: 'add_customer.label_last_name'.tr,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.email,
            fieldKey: const ValueKey('customer-form-email'),
            label: 'add_customer.label_email'.tr,
            keyboardType: TextInputType.emailAddress,
            validator: form.validateEmail,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.phone,
            fieldKey: const ValueKey('customer-form-phone'),
            label: 'add_customer.label_phone'.tr,
            required: true,
            keyboardType:
                form.isEdit ? TextInputType.phone : TextInputType.number,
            // Edit mode keeps the stored number as typed so an untouched
            // phone is not reported as changed.
            inputFormatters:
                form.isEdit ? null : const [PhoneNumberFormatter()],
            validator: form.validatePhone,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.altPhone,
            fieldKey: const ValueKey('customer-form-alt-phone'),
            label: 'add_customer.label_alt_phone'.tr,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          AppDropdownField<String>(
            label: 'add_customer.label_gender'.tr,
            hint: 'add_customer.hint_select_gender'.tr,
            value: form.gender,
            items: [
              for (final gender in genders)
                DropdownMenuItem(value: gender, child: Text(_gender(gender))),
            ],
            onChanged: form.setGender,
          ),
          AppTextField(
            controller: form.dateOfBirth,
            label: 'add_customer.label_dob'.tr,
            hint: 'customer_profile.field_dob_hint'.tr,
            icon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: onPickDateOfBirth,
          ),
        ],
      ),
    );
  }

  static String _gender(String value) => switch (value) {
        'male' => 'add_customer.gender_male'.tr,
        'female' => 'add_customer.gender_female'.tr,
        'other' => 'add_customer.gender_other'.tr,
        _ => value,
      };
}

/// Customer type with CR and VAT number (required for B2B when creating).
class CustomerBusinessSection extends StatelessWidget {
  const CustomerBusinessSection({super.key, required this.form});

  final CustomerFormController form;

  @override
  Widget build(BuildContext context) {
    final requireNumbers = !form.isEdit && form.isBusinessCustomer;
    return SectionCard(
      title: 'customers.form.section_business'.tr,
      icon: Icons.business_outlined,
      child: ResponsiveFieldGrid(
        children: [
          AppRadioGroupField<CustomerType>(
            label: 'add_customer.label_customer_type'.tr,
            required: true,
            value: CustomerType.parse(form.customerType),
            options: CustomerType.values,
            optionLabel: (type) => type == CustomerType.b2b
                ? 'customers.type_b2b'.tr
                : 'customers.type_b2c'.tr,
            onChanged: (type) => form.setCustomerType(type.apiValue),
          ),
          AppTextField(
            controller: form.crNumber,
            fieldKey: const ValueKey('customer-form-cr-number'),
            label: 'add_customer.label_cr_number'.tr,
            required: requireNumbers,
            validator: form.validateCrNumber,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.vatNumber,
            fieldKey: const ValueKey('customer-form-vat-number'),
            label: 'add_customer.label_vat_number'.tr,
            required: requireNumbers,
            validator: form.validateVatNumber,
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }
}

/// Balance amount and whether it is to pay or to receive.
class CustomerBalanceSection extends StatelessWidget {
  const CustomerBalanceSection({super.key, required this.form});

  final CustomerFormController form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customers.form.section_account'.tr,
      icon: Icons.account_balance_wallet_outlined,
      child: ResponsiveFieldGrid(
        maxColumns: 2,
        children: [
          AppTextField(
            controller: form.balance,
            fieldKey: const ValueKey('customer-form-balance'),
            label: 'add_customer.label_balance'.tr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
            ],
            validator: form.validateBalance,
          ),
          AppRadioGroupField<CustomerPaymentType>(
            label: 'add_customer.label_payment_type'.tr,
            value: form.paymentType == CustomerPaymentType.none
                ? null
                : form.paymentType,
            options: const [
              CustomerPaymentType.toPay,
              CustomerPaymentType.toReceive,
            ],
            optionLabel: (type) => type == CustomerPaymentType.toPay
                ? 'add_customer.payment_to_pay'.tr
                : 'add_customer.payment_to_receive'.tr,
            onChanged: form.setPaymentType,
          ),
        ],
      ),
    );
  }
}
