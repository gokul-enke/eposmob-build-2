import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// A reusable checkout footer widget that displays payment summary
/// including net amount, discount, tax, total payable, total paid, and balance.
class CheckoutFooter extends StatelessWidget {
  /// The price summary containing all payment calculations
  final PriceSummary? priceSummary;

  /// Currency symbol (e.g., 'SAR', '$', '€')
  final String currency;

  /// Map of tax names to their percentages for displaying tax details
  final Map<String, num> taxNames;

  /// Total amount paid by the customer
  final double totalPaid;

  /// Balance amount (can be positive or negative)
  final double balance;

  /// Callback when tax row is tapped to show tax details
  final VoidCallback? onTaxTap;

  /// Custom text style for the total payable row title
  final TextStyle? totalPayableTitleStyle;

  /// Custom text style for the total payable row amount
  final TextStyle? totalPayableAmountStyle;

  /// Custom padding for the container
  final EdgeInsetsGeometry padding;

  /// Custom border radius for the container
  final double borderRadius;

  /// Background color of the container
  final Color backgroundColor;

  /// Whether to show the discount row (only shown if discount > 0)
  final bool showDiscount;

  /// Whether to show the total paid row
  final bool showTotalPaid;

  /// Whether to show the balance row
  final bool showBalance;

  /// Whether the tax row is tappable to show details
  final bool enableTaxTap;

  const CheckoutFooter({
    Key? key,
    required this.priceSummary,
    required this.currency,
    this.taxNames = const {},
    this.totalPaid = 0.0,
    this.balance = 0.0,
    this.onTaxTap,
    this.totalPayableTitleStyle,
    this.totalPayableAmountStyle,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 8.0,
    this.backgroundColor = Colors.white,
    this.showDiscount = true,
    this.showTotalPaid = true,
    this.showBalance = true,
    this.enableTaxTap = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (priceSummary == null) {
      return const SizedBox.shrink();
    }

    final discount = priceSummary!.discount ?? 0;

    return BuildBoxShadowContainer(
      circleRadius: borderRadius,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Net Amount
          BuildPaymentRow(
            title: 'billing.net_amount'.tr,
            amount:
                '$currency ${AmountHelper.formatAmount(priceSummary!.netTotal ?? 0)}',
            color: ColorManager.textColor,
            padding: EdgeInsets.zero,
          ),

          // Discount (only if > 0 and showDiscount is true)
          if (showDiscount && discount > 0) ...[
            const SizedBox(height: 6),
            BuildPaymentRow(
              title: 'billing.discount'.tr,
              amount: '-$currency ${AmountHelper.formatAmount(discount)}',
              color: ColorManager.kButtonRed,
              padding: EdgeInsets.zero,
            ),
          ],

          const SizedBox(height: 6),

          // Tax
          GestureDetector(
            onTap: enableTaxTap ? onTaxTap : null,
            child: BuildPaymentRow(
              title: 'billing.tax'.tr,
              amount:
                  '$currency ${AmountHelper.formatAmount(priceSummary!.totalTax ?? 0)}',
              color: ColorManager.kGreyColor,
              padding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Total Payable
          BuildPaymentRow(
            title: 'billing.total_payable_label'.tr,
            amount:
                '$currency ${AmountHelper.formatAmount(priceSummary!.netPayable ?? 0)}',
            color: ColorManager.kPrimaryColor,
            padding: EdgeInsets.zero,
            firstRowTextStyle: totalPayableTitleStyle ??
                buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s15,
                  0.18,
                  ColorManager.kPrimaryColor,
                ),
            secondRowTextStyle: totalPayableAmountStyle ??
                buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s16,
                  0.18,
                  ColorManager.kPrimaryColor,
                ),
          ),

          // Total Paid
          if (showTotalPaid) ...[
            const SizedBox(height: 8),
            BuildPaymentRow(
              title: 'billing.total_paid'.tr,
              amount: '$currency ${AmountHelper.formatAmount(totalPaid)}',
              color: ColorManager.textColor,
              padding: EdgeInsets.zero,
            ),
          ],

          // Balance
          if (showBalance) ...[
            const SizedBox(height: 6),
            BuildPaymentRow(
              title: 'billing.balance'.tr,
              amount: '$currency ${AmountHelper.formatAmount(balance)}',
              color: balance > 0
                  ? ColorManager.kButtonRed
                  : ColorManager.kButtonGreen,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}
