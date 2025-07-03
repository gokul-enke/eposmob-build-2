import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class BillingPaymentSummary extends StatelessWidget {
  final Map<String, num> taxNames;

  const BillingPaymentSummary({
    Key? key,
    required this.taxNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localProductProvider = Provider.of<LocalProductProvider>(context, listen: true);

    localProductProvider.cartTotal; // Call this to ensure priceSummary is set
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BuildPaymentRow(
          amount: "",
          title: "Payment Summary",
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            ColorManager.kPrimaryColor,
          ),
          color: ColorManager.kPrimaryColor,
        ),
        const SizedBox(
          height: 5,
        ),
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal ?? 0.00)}",
          title: "Net amount",
          color: ColorManager.textColor,
        ),
        const BuildPaymentRow(
          amount: "INR 0.00",
          title: "Shipping",
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount ?? 0.00)}",
          title: "Discount",
          color: ColorManager.textColor,
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount:
                "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax ?? 0.00)}",
            title: "GST",
            color: ColorManager.kPrimaryColor,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Center(
                  child: TaxDetailsDialog(
                    taxAmounts: taxNames,
                  ),
                );
              },
            );
          },
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(localProductProvider.cartTotal)}", // Use cartTotal from LocalProductProvider
          title: "Total Payable",
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColor,
          ),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColor,
          ),
          color: ColorManager.textColor,
        ),
      ],
    );
  }
} 