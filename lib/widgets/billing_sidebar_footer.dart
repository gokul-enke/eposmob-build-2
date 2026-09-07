import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

class BillingSidebarFooter extends StatelessWidget {
  // Customer
  final TextEditingController mobileNumberTextController;
  final String? mobileNumberText;
  final bool isCustomerFound;
  final int? selectedCustomerID;
  final VoidCallback onClearCustomer;
  final Function(String) onCustomerChanged;
  final Function(CustomerListModelData) onCustomerSelected;
  final List<CustomerListModelData> customerOptions;

  // Selected states for quick actions
  final bool isDiscountSelected;
  final bool isDeliverySelected;
  final bool isPaymentSelected;

  // Selected values to display
  final String? selectedDiscountValue;  // e.g., "-SAR 10.00" or "10%"
  final String? selectedDeliveryMethod; // e.g., "Door Delivery"
  final String? selectedPaymentMethod;  // e.g., "Cash", "Card"

  // Customer info
  final String? selectedCustomerName;   // e.g., "Default CUSTOMER"
  final String? selectedCustomerPhone;  // e.g., "7034598461"

  // Payment status
  final double totalPaid;
  final double balance;

  // Payment Summary
  final PriceSummary? priceSummary;
  final String currency;
  final Map<String, num> taxNames;
  final VoidCallback onTaxTap;

  // Quick Actions
  final VoidCallback onDiscountTap;
  final VoidCallback onDeliveryTap;
  final VoidCallback onPaymentTap;

  // Action Buttons
  final VoidCallback onClearCart;
  final VoidCallback onSaveOrder;
  final VoidCallback onConfirmAndPrint;
  final bool isLoadingClearCart;
  final bool isLoadingSaveOrder;
  final bool isLoadingConfirmOrder;

  // Size constraints
  final double height;
  final double width;

  const BillingSidebarFooter({
    Key? key,
    required this.mobileNumberTextController,
    this.mobileNumberText,
    required this.isCustomerFound,
    this.selectedCustomerID,
    required this.onClearCustomer,
    required this.onCustomerChanged,
    required this.onCustomerSelected,
    required this.customerOptions,
    this.isDiscountSelected = false,
    this.isDeliverySelected = false,
    this.isPaymentSelected = false,
    this.selectedDiscountValue,
    this.selectedDeliveryMethod,
    this.selectedPaymentMethod,
    this.selectedCustomerName,
    this.selectedCustomerPhone,
    this.totalPaid = 0.0,
    this.balance = 0.0,
    this.priceSummary,
    required this.currency,
    required this.taxNames,
    required this.onTaxTap,
    required this.onDiscountTap,
    required this.onDeliveryTap,
    required this.onPaymentTap,
    required this.onClearCart,
    required this.onSaveOrder,
    required this.onConfirmAndPrint,
    this.isLoadingClearCart = false,
    this.isLoadingSaveOrder = false,
    this.isLoadingConfirmOrder = false,
    required this.height,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer Row
          _buildCustomerRow(),
          const SizedBox(height: 10),

          // Quick Icons Row
          _buildQuickIconsRow(),
          const SizedBox(height: 10),

          // Payment Summary
          _buildPaymentSummary(),
          const SizedBox(height: 12),

          // Action Buttons Row
          _buildActionButtonsRow(),
        ],
      ),
    );
  }

  Widget _buildCustomerRow() {
    if (isCustomerFound && selectedCustomerName != null) {
      return BuildBoxShadowContainer(
        circleRadius: 6,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Text('👤 ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                selectedCustomerName!,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.16,
                  ColorManager.textColor,
                ),
              ),
            ),
            if (selectedCustomerPhone != null)
              Text(
                selectedCustomerPhone!,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.16,
                  ColorManager.grey,
                ),
              ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClearCustomer,
              child: Container(
                padding: const EdgeInsets.all(2),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: ColorManager.kButtonRed,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return BuildBoxShadowContainer(
      circleRadius: 6,
      padding: EdgeInsets.zero,
      child: Autocomplete<CustomerListModelData>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<CustomerListModelData>.empty();
          }
          return customerOptions.where((CustomerListModelData option) {
            return option.name
                    ?.toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()) ??
                false ||
                    (option.phone ?? '')
                        .contains(textEditingValue.text);
          });
        },
        onSelected: (CustomerListModelData selection) {
          onCustomerSelected(selection);
        },
        fieldViewBuilder: (BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted) {
          mobileNumberTextController.text = mobileNumberText ?? '';
          return TextField(
            controller: fieldTextEditingController..text = mobileNumberText ?? '',
            focusNode: fieldFocusNode,
            onChanged: (value) {
              onCustomerChanged(value);
            },
            decoration: InputDecoration(
              hintText: 'Search customer...',
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.16,
                ColorManager.grey,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.16,
              ColorManager.textColor,
            ),
          );
        },
        optionsViewBuilder: (BuildContext context,
            AutocompleteOnSelected<CustomerListModelData> onSelected,
            Iterable<CustomerListModelData> options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 150),
                width: width,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final CustomerListModelData option =
                        options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (option.name == null ||
                                      option.name!.trim().isEmpty ||
                                      option.name!.trim().toLowerCase() ==
                                          'no name')
                                  ? 'customers.unnamed'.tr
                                  : option.name!.trim(),
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.16,
                                ColorManager.textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              option.phone ?? '',
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s11,
                                0.16,
                                ColorManager.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickIconsRow() {
    return Row(
      children: [
        _buildQuickIconButton(
          icon: Icons.local_offer_outlined,
          label: 'Discount',
          color: ColorManager.kButtonYellow,
          onTap: onDiscountTap,
          isSelected: isDiscountSelected,
          selectedValue: selectedDiscountValue,
        ),
        const SizedBox(width: 8),
        _buildQuickIconButton(
          icon: Icons.delivery_dining_outlined,
          label: 'Delivery',
          color: ColorManager.kButtonGreen,
          onTap: onDeliveryTap,
          isSelected: isDeliverySelected,
          selectedValue: selectedDeliveryMethod,
        ),
        const SizedBox(width: 8),
        _buildQuickIconButton(
          icon: Icons.payment_outlined,
          label: 'Payment',
          color: ColorManager.kButtonBlue,
          onTap: onPaymentTap,
          isSelected: isPaymentSelected,
          selectedValue: selectedPaymentMethod,
        ),
      ],
    );
  }

  Widget _buildQuickIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSelected = false,
    String? selectedValue,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: selectedValue != null ? 8 : 6,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.16,
                      isSelected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
              if (selectedValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  selectedValue,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.16,
                    isSelected ? Colors.white : color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    if (priceSummary == null) {
      return const SizedBox.shrink();
    }

    final discount = priceSummary!.discount ?? 0;

    return BuildBoxShadowContainer(
      circleRadius: 6,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          BuildPaymentRow(
            title: 'Net Amount',
            amount: '$currency ${AmountHelper.formatAmount(priceSummary!.netTotal ?? 0)}',
            color: ColorManager.textColor,
            padding: EdgeInsets.zero,
          ),
          if (discount > 0) ...[
            const SizedBox(height: 6),
            BuildPaymentRow(
              title: 'Discount',
              amount: '-$currency ${AmountHelper.formatAmount(discount)}',
              color: ColorManager.kButtonRed,
              padding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTaxTap,
            child: BuildPaymentRow(
              title: 'Tax',
              amount: '$currency ${AmountHelper.formatAmount(priceSummary!.totalTax ?? 0)}',
              color: ColorManager.kGreyColor,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          BuildPaymentRow(
            title: 'Total Payable',
            amount: '$currency ${AmountHelper.formatAmount(priceSummary!.netPayable ?? 0)}',
            color: ColorManager.kPrimaryColor,
            padding: EdgeInsets.zero,
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.18,
              ColorManager.kPrimaryColor,
            ),
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          BuildPaymentRow(
            title: 'Total Paid',
            amount: '$currency ${AmountHelper.formatAmount(totalPaid)}',
            color: ColorManager.textColor,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 6),
          BuildPaymentRow(
            title: 'Balance',
            amount: '$currency ${AmountHelper.formatAmount(balance)}',
            color: balance > 0 ? ColorManager.kButtonRed : ColorManager.kButtonGreen,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        Expanded(
          child: CustomRoundButton(
            title: 'Clear Cart',
            fct: onClearCart,
            height: 38,
            width: double.infinity,
            fontSize: FontSize.s12,
            boxColor: ColorManager.kButtonRed,
            isLoading: isLoadingClearCart,
            radius: 6,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomRoundButton(
            title: 'Save Order',
            fct: onSaveOrder,
            height: 38,
            width: double.infinity,
            fontSize: FontSize.s12,
            boxColor: ColorManager.kButtonYellow,
            isLoading: isLoadingSaveOrder,
            radius: 6,
            textColor: Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomRoundButton(
            title: 'Confirm & Print',
            fct: onConfirmAndPrint,
            height: 38,
            width: double.infinity,
            fontSize: FontSize.s12,
            boxColor: ColorManager.kButtonBlue,
            isLoading: isLoadingConfirmOrder,
            radius: 6,
          ),
        ),
      ],
    );
  }
}
