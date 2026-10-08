part of 'sales_return_form_view.dart';

extension _PaymentMethodSection on SalesReturnFormSections {
  Widget _paymentMethodField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sales_return_form.payment_method_label'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.25,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: DropdownButtonFormField<String>(
              value: selectedPaymentMethod,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                ColorManager.textColor,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12, vertical: 12),
                constraints: const BoxConstraints.tightFor(height: 48),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: ColorManager.kPrimaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_drop_down),
              iconSize: 20,
              items: paymentMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentMethodIcon(method),
                        size: 16,
                        color: ColorManager.kPrimaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        method,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s14,
                          0.25,
                          ColorManager.textColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedPaymentMethod = newValue;
                  });
                }
              },
            ),
          ),
        ],
      );
}
