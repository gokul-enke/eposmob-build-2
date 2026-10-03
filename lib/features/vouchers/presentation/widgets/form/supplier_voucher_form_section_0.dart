part of 'supplier_voucher_form_view.dart';

extension _SupplierVoucherFormSection0 on SupplierVoucherFormView {
  Widget _buildSummaryLine(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value.isEmpty ? '0' : value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
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
          'supplier_voucher.type_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          focusNode: form.typeFocus,
          title: null,
          showName: false,
          hintText: 'supplier_voucher.select_type_hint'.tr,
          value: form.selectedType,
          items: form.typeOptions.map((t) => t['value']!).toList(),
          onChanged: (String? value) {
            form.update(() => form.selectedType = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null) return 'supplier_voucher.select_type_hint'.tr;
            switch (value) {
              case 'order':
                return 'supplier_voucher.type_order'.tr;
              case 'discount':
                return 'supplier_voucher.type_discount'.tr;
              case 'other':
                return 'supplier_voucher.type_other'.tr;
              default:
                return 'general.unknown'.tr;
            }
          },
          height: 45,
        ),
      ],
    );
  }

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

  Widget _buildPaymentMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'supplier_voucher.payment_method_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          focusNode: form.paymentMethodFocus,
          title: null,
          showName: false,
          hintText: form.isLoadingPaymentMethods
              ? 'supplier_voucher.loading'.tr
              : 'supplier_voucher.select_payment_method_hint'.tr,
          value: form.selectedPaymentMethod,
          items: form.paymentMethods.map((m) => m.value).toList(),
          onChanged: (String? value) {
            form.update(() => form.selectedPaymentMethod = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null)
              return 'supplier_voucher.select_payment_method_hint'.tr;
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

  Widget _buildSupplierDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'supplier_voucher.supplier_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<int>(
          focusNode: form.supplierFocus,
          title: null,
          showName: false,
          hintText: 'supplier_voucher.select_supplier_hint'.tr,
          value: form.selectedSupplierId,
          items: form.suppliers.map((c) => c['id'] as int).toList(),
          onChanged: (int? value) {
            form.update(() {
              form.selectedSupplierId = value;
              if (value != null) {
                final supplier = form.suppliers
                    .firstWhere((c) => c['id'] == value, orElse: () => {});
                form.selectedSupplierName =
                    supplier['name'] ?? supplier['user']?['name'] ?? '';
              }
            });
            // Focus will move to first item name field
          },
          displayText: (int? id) {
            if (id == null) return 'supplier_voucher.select_supplier_hint'.tr;
            final supplier = form.suppliers
                .firstWhere((c) => c['id'] == id, orElse: () => {});
            return supplier['name'] ??
                supplier['user']?['name'] ??
                'general.unknown'.tr;
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
                'supplier_voucher.col_item_name_required'.tr,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'supplier_voucher.col_unit_amount_required'.tr,
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
                'supplier_voucher.col_tax_percent'.tr,
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
                'supplier_voucher.col_quantity'.tr,
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
                'supplier_voucher.col_total'.tr,
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
