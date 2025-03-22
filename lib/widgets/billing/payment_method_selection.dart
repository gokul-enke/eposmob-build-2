import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:websafe_svg/websafe_svg.dart';

class PaymentMethodSelection extends StatelessWidget {
  final int iconColor;
  final Function(int) onPaymentMethodSelected;
  final TextEditingController transactionNumberController;
  final TextEditingController paidAmountController;
  final double balanceAmount;
  final void Function(String?) onPaidAmountChanged;
  
  const PaymentMethodSelection({
    Key? key,
    required this.iconColor,
    required this.onPaymentMethodSelected,
    required this.transactionNumberController,
    required this.paidAmountController,
    required this.balanceAmount,
    required this.onPaidAmountChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    
    return Column(
      children: [
        BuildPaymentRow(
          amount: "",
          title: "Payment Method",
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            ColorManager.kPrimaryColor,
          ),
          color: ColorManager.kPrimaryColor,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                onPaymentMethodSelected(1);
              },
              child: BuildBoxShadowContainer(
                border: iconColor == 1
                    ? Border.all(color: ColorManager.kPrimaryColor)
                    : null,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(8),
                blurRadius: 4,
                circleRadius: 5,
                child: Column(
                  children: [
                    WebsafeSvg.asset(
                      ImageAssets.cashIcon,
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Cash',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s10, 0.12, Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                onPaymentMethodSelected(2);
              },
              child: BuildBoxShadowContainer(
                border: iconColor == 2
                    ? Border.all(color: ColorManager.kPrimaryColor)
                    : null,
                margin: const EdgeInsets.only(left: 10, top: 10),
                padding: const EdgeInsets.only(
                    left: 12, top: 8, bottom: 8, right: 12),
                blurRadius: 4,
                circleRadius: 5,
                child: Column(
                  children: [
                    WebsafeSvg.asset(
                      ImageAssets.creditCardIcon,
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Card',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s10, 0.12, Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                onPaymentMethodSelected(3);
              },
              child: BuildBoxShadowContainer(
                border: iconColor == 3
                    ? Border.all(color: ColorManager.kPrimaryColor)
                    : null,
                margin: const EdgeInsets.only(left: 10, top: 10),
                padding: const EdgeInsets.only(
                    left: 12, top: 8, bottom: 8, right: 12),
                blurRadius: 4,
                circleRadius: 5,
                child: Column(
                  children: [
                    WebsafeSvg.asset(
                      ImageAssets.creditCardIcon,
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Upi',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s10, 0.12, Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            if (iconColor == 2 || iconColor == 3 || iconColor == 1)
              Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: iconColor != 1
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: buildColumnWidgetForTextFields(
                              controller: transactionNumberController,
                              size: size,
                              height: size.height * .06,
                              hintText: 'Transaction Reference No:',
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: buildColumnWidgetForTextFields(
                              controller: paidAmountController,
                              size: size,
                              onchanged: onPaidAmountChanged,
                              height: size.height * .06,
                              hintText: 'Enter Paid Amount Here:',
                            ),
                          )),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (iconColor == 1)
          BuildPaymentRow(
            amount: "INR ${balanceAmount.toStringAsFixed(2)}",
            title: "Balance amount",
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s15,
              0.18,
              ColorManager.textColorRed,
            ),
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.textColorRed,
            ),
            color: ColorManager.textColorRed,
          ),
        if (iconColor == 1) const SizedBox(height: 10),
      ],
    );
  }
} 