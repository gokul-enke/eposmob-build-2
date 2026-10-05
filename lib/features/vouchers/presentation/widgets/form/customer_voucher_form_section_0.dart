part of 'customer_voucher_form_view.dart';

extension _CustomerVoucherFormSection0 on CustomerVoucherFormView {
  Widget _buildDateField(
    String label,
    DateTime selectedDate,
    Function(DateTime) onDateSelected,
    FocusNode focusNode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: CalendarPickerTableCell(
            focusNode: focusNode,
            onDateSelected: onDateSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'customer_voucher.type_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          focusNode: form.typeFocus,
          title: null,
          showName: false,
          hintText: 'customer_voucher.select_type_hint'.tr,
          value: form.selectedType,
          items: form.typeOptions.map((t) => t['value']!).toList(),
          onChanged: (String? value) {
            form.update(() => form.selectedType = value);
            // Move focus to voucher date after selection
            FocusScope.of(context).requestFocus(form.voucherDateFocus);
          },
          displayText: (String? value) {
            if (value == null) return 'customer_voucher.select_type_hint'.tr;
            switch (value) {
              case 'order':
                return 'customer_voucher.type_order'.tr;
              case 'discount':
                return 'customer_voucher.type_discount'.tr;
              case 'sales_return':
                return 'customer_voucher.type_sales_return'.tr;
              case 'other':
                return 'customer_voucher.type_other'.tr;
              default:
                return 'general.unknown'.tr;
            }
          },
          height: 45,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'customer_voucher.payment_method_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          focusNode: form.paymentMethodFocus,
          title: null,
          showName: false,
          hintText: form.isLoadingPaymentMethods
              ? 'customer_voucher.loading'.tr
              : 'customer_voucher.select_payment_method_hint'.tr,
          value: form.selectedPaymentMethod,
          items: form.paymentMethods.map((m) => m.value).toList(),
          onChanged: (String? value) {
            form.update(() => form.selectedPaymentMethod = value);
            // Move focus to customer after selection
            FocusScope.of(context).requestFocus(form.customerFocus);
          },
          displayText: (String? value) {
            if (value == null)
              return 'customer_voucher.select_payment_method_hint'.tr;
            try {
              return form.paymentMethods
                  .firstWhere((m) => m.value == value)
                  .description;
            } catch (e) {
              return value;
            }
          },
          height: 45,
        ),
      ],
    );
  }

  // Helper method to get payment method ID for API

  Widget _buildCustomerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'customer_voucher.customer_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<int>(
          focusNode: form.customerFocus,
          title: null,
          showName: false,
          hintText: 'customer_voucher.select_customer_hint'.tr,
          value: form.selectedCustomerId,
          items: form.customers.map((c) => c['id'] as int).toList(),
          onChanged: (int? value) {
            form.update(() {
              form.selectedCustomerId = value;
              if (value != null) {
                final customer = form.customers
                    .firstWhere((c) => c['id'] == value, orElse: () => {});
                form.selectedCustomerName = customer['name'] ?? '';
              }
            });
            // Move focus to first item's name field after selection
            if (form.voucherItems.isNotEmpty) {
              FocusScope.of(context)
                  .requestFocus(form.voucherItems[0].itemNameFocus);
            }
          },
          displayText: (int? id) {
            if (id == null) return 'customer_voucher.select_customer_hint'.tr;
            final customer = form.customers
                .firstWhere((c) => c['id'] == id, orElse: () => {});
            return customer['name'] ?? 'general.unknown'.tr;
          },
          height: 45,
        ),
      ],
    );
  }

  Widget _buildItemsTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.tableBGColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'customer_voucher.col_item_name_required'.tr,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'customer_voucher.col_unit_amount_required'.tr,
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          // Expanded(
          //   child: Padding(
          //     padding: const EdgeInsets.all(12.0),
          //     child: Text(
          //       'Tax',
          //       textAlign: TextAlign.center,
          //       style: buildCustomStyle(FontWeightManager.semiBold,
          //           FontSize.s11, 0.18, ColorManager.kPrimaryColor),
          //     ),
          //   ),
          // ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'customer_voucher.col_quantity'.tr,
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'customer_voucher.col_total'.tr,
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
