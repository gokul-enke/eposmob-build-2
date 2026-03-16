import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_tax_modal.dart';

class PaymentSummary extends StatelessWidget {
  final bool compact;
  const PaymentSummary({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: true);
    final billingProvider = Provider.of<BillingProvider>(context, listen: true);
    final deliveryMethodsProvider =
      Provider.of<DeliveryMethodsProvider>(context, listen: true);
    final currency = appSettingsProvider.appSettings?.currency ?? '';

    final thresholdEnabled =
      appSettingsProvider.appSettings?.freeDeliveryEnabled ??
        false;
    final thresholdAmount = double.tryParse(
        appSettingsProvider.appSettings?.freeDeliveryMinimumAmount.trim() ??
          '',
      ) ??
      0.0;

    final discountedTotalForThreshold =
      localProductProvider.priceSummary?.netTotal ?? localProductProvider.cartTotal;

    double deliveryCharge = 0.0;
    if (thresholdEnabled &&
      !(thresholdAmount > 0 && discountedTotalForThreshold >= thresholdAmount)) {
      final selectedMethodId = billingProvider.deliveryMethodId;
      final selectedMethodName = billingProvider.deliveryMethod;

      for (final method in deliveryMethodsProvider.deliveryMethods) {
      if ((selectedMethodId.isNotEmpty && method.id == selectedMethodId) ||
        (selectedMethodName.isNotEmpty && method.name == selectedMethodName)) {
        deliveryCharge = method.basePrice ?? 0.0;
        break;
      }
      }
    }

    // Ensure priceSummary is computed
    localProductProvider.cartTotal;

    // Keep provider's total order amount in sync with cart total
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final netTotal =
          localProductProvider.priceSummary?.netTotal ?? localProductProvider.cartTotal;
      billingProvider.setTotalOrderAmount(netTotal + deliveryCharge);
    });

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
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
          const SizedBox(height: 5),
          BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}",
            title: "Net amount",
            color: ColorManager.textColor,
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s15,
              0.18,
              ColorManager.textColor,
            ),
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s15,
              0.18,
              ColorManager.textColor,
            ),
          ),
          (Provider.of<AppSettingsProvider>(context, listen: false)
                      .appSettings
                      ?.priceRoundOff ==
                  true)
              ? BuildPaymentRow(
                  amount:
                      "$currency ${AmountHelper.roundOffAmount(localProductProvider.priceSummary!.discount)} (${(localProductProvider.priceSummary!.subTotal > 0 ? ((localProductProvider.priceSummary!.discount / localProductProvider.priceSummary!.subTotal) * 100) : 0.0).toStringAsFixed(1)}%)",
                  title: "Discount",
                  color: ColorManager.kButtonGreen,
                  firstRowTextStyle: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                  secondRowTextStyle: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                )
              : BuildPaymentRow(
                  amount:
                      "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)} (${(localProductProvider.priceSummary!.subTotal > 0 ? ((localProductProvider.priceSummary!.discount / localProductProvider.priceSummary!.subTotal) * 100) : 0.0).toStringAsFixed(1)}%)",
                  title: "Discount",
                  color: ColorManager.kButtonGreen,
                  firstRowTextStyle: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                  secondRowTextStyle: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s15,
                    0.18,
                    ColorManager.kButtonGreen,
                  ),
                ),
          if (deliveryCharge > 0)
            BuildPaymentRow(
              amount: "$currency ${AmountHelper.formatAmount(deliveryCharge)}",
              title: "Delivery Charge",
              color: ColorManager.textColor,
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                ColorManager.textColor,
              ),
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.18,
                ColorManager.textColor,
              ),
            ),
          const Divider(thickness: 2),
          BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.roundOffAmount(localProductProvider.cartTotal + deliveryCharge)}",
            title: "Total Payable",
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.kPrimaryColor,
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

    String getFormattedTotal() {
      if (appSettingsProvider.appSettings?.priceRoundOff == true) {
        double roundedTotal = localProductProvider.getRoundedTotal(context);
        return AmountHelper.formatAmount(roundedTotal + deliveryCharge);
      }
      return AmountHelper.formatAmount(localProductProvider.cartTotal + deliveryCharge);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
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
        const SizedBox(height: 5),
        BuildPaymentRow(
          amount:
              "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}",
          title: "Net amount",
          color: ColorManager.textColor,
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
        ),
        if (deliveryCharge > 0)
          BuildPaymentRow(
            amount: "$currency ${AmountHelper.formatAmount(deliveryCharge)}",
            title: "Delivery Charge",
            color: ColorManager.textColor,
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s15,
              0.18,
              ColorManager.textColor,
            ),
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s15,
              0.18,
              ColorManager.textColor,
            ),
          ),
        BuildPaymentRow(
          amount:
              "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)} (${(localProductProvider.priceSummary!.subTotal > 0 ? ((localProductProvider.priceSummary!.discount / localProductProvider.priceSummary!.subTotal) * 100) : 0.0).toStringAsFixed(1)}%)",
          title: "Discount",
          color: ColorManager.textColor,
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s15,
            0.18,
            ColorManager.textColor,
          ),
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax)}",
            title: "GST",
            color: ColorManager.kPrimaryColor,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Center(
                  child: TaxDetailsDialog(
                    taxAmounts:
                        Provider.of<BillingProvider>(context, listen: false)
                            .taxNames,
                  ),
                );
              },
            );
          },
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount: "$currency ${getFormattedTotal()}",
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
