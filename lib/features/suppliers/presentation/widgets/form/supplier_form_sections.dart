import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/utils/phone_number_formatter.dart';

import '../../state/supplier_form_controller.dart';

/// Name, contact numbers, email and tax number.
class SupplierDetailsSection extends StatelessWidget {
  const SupplierDetailsSection({
    super.key,
    required this.form,
    this.nameFocus,
  });

  final SupplierFormController form;
  final FocusNode? nameFocus;

  @override
  Widget build(BuildContext context) {
    // Edit mode keeps stored numbers as typed (no dash formatting).
    final phoneFormatters = form.isEdit ? null : const [PhoneNumberFormatter()];
    final phoneKeyboard =
        form.isEdit ? TextInputType.phone : TextInputType.number;
    return SectionCard(
      title: 'supplier_profile.edit_section_basic'.tr,
      icon: Icons.business_outlined,
      child: ResponsiveFieldGrid(
        maxColumns: 2,
        children: [
          AppTextField(
            controller: form.name,
            fieldKey: const ValueKey('supplier-form-name'),
            focusNode: nameFocus,
            label: 'add_supplier.field_name'.tr,
            hint: 'supplier_profile.edit_hint_name'.tr,
            required: true,
            validator: form.validateName,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.email,
            fieldKey: const ValueKey('supplier-form-email'),
            label: 'add_supplier.field_email'.tr,
            hint: 'supplier_profile.edit_hint_email'.tr,
            keyboardType: TextInputType.emailAddress,
            validator: form.validateEmail,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.phone,
            fieldKey: const ValueKey('supplier-form-phone'),
            label: 'add_supplier.field_phone'.tr,
            hint: 'supplier_profile.edit_hint_phone'.tr,
            required: true,
            keyboardType: phoneKeyboard,
            inputFormatters: phoneFormatters,
            validator: form.validatePhone,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.altPhone,
            fieldKey: const ValueKey('supplier-form-alt-phone'),
            label: 'add_supplier.field_alt_phone'.tr,
            hint: 'supplier_profile.edit_hint_alt_phone'.tr,
            keyboardType: phoneKeyboard,
            inputFormatters: phoneFormatters,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.taxNumber,
            fieldKey: const ValueKey('supplier-form-tax-number'),
            label: 'add_supplier.field_tax_number'.tr,
            hint: 'supplier_profile.edit_hint_tax'.tr,
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }
}

/// Business address.
class SupplierAddressSection extends StatelessWidget {
  const SupplierAddressSection({super.key, required this.form});

  final SupplierFormController form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'supplier_profile.edit_section_address'.tr,
      icon: Icons.location_on_outlined,
      child: AppTextField(
        controller: form.address,
        fieldKey: const ValueKey('supplier-form-address'),
        label: 'add_supplier.field_address'.tr,
        hint: 'supplier_profile.edit_hint_address'.tr,
        maxLines: 3,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}

/// CR and VAT numbers.
class SupplierKycSection extends StatelessWidget {
  const SupplierKycSection({super.key, required this.form});

  final SupplierFormController form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'add_supplier.section_kyc'.tr,
      icon: Icons.verified_user_outlined,
      child: ResponsiveFieldGrid(
        maxColumns: 2,
        children: [
          AppTextField(
            controller: form.crNumber,
            fieldKey: const ValueKey('supplier-form-cr-number'),
            label: 'add_supplier.field_cr_number'.tr,
            hint: 'supplier_profile.edit_hint_cr'.tr,
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            controller: form.vatNumber,
            fieldKey: const ValueKey('supplier-form-vat-number'),
            label: 'add_supplier.field_vat_number'.tr,
            hint: 'supplier_profile.edit_hint_vat'.tr,
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }
}

/// Balance amount and whether it is to pay or to receive.
class SupplierBalanceSection extends StatelessWidget {
  const SupplierBalanceSection({super.key, required this.form});

  final SupplierFormController form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'supplier_profile.edit_section_financial'.tr,
      icon: Icons.account_balance_wallet_outlined,
      child: ResponsiveFieldGrid(
        maxColumns: 2,
        children: [
          AppTextField(
            controller: form.balance,
            fieldKey: const ValueKey('supplier-form-balance'),
            label: form.isEdit
                ? 'supplier_profile.edit_label_balance'.tr
                : 'add_supplier.field_opening_balance'.tr,
            hint: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
            ],
            validator: form.validateBalance,
          ),
          AppRadioGroupField<SupplierPaymentType>(
            label: 'supplier_profile.edit_label_payment_type'.tr,
            required: true,
            value: form.paymentType,
            options: SupplierPaymentType.values,
            optionLabel: (type) => type == SupplierPaymentType.toPay
                ? 'add_supplier.payment_to_pay'.tr
                : 'add_supplier.payment_to_receive'.tr,
            onChanged: form.setPaymentType,
          ),
        ],
      ),
    );
  }
}
