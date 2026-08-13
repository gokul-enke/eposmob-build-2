import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/features/billing/domain/billing_totals.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
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

  /// When false, hides the bare to-customer-credit toggle (mobile uses a
  /// dedicated section in [PaymentMethodsSection] instead).
  final bool showToCustomerCreditToggle;

  /// When false, the tax row is plain text (no underline, no breakdown dialog).
  /// Desktop keeps the default `true`; mobile billing passes `false`.
  final bool taxBreakdownEnabled;

  /// When true (and [taxBreakdownEnabled] is true), opens tax details in a
  /// bottom sheet instead of a centered dialog — intended for mobile billing.
  final bool taxBreakdownUseBottomSheet;
  const PaymentSummary({
    super.key,
    this.compact = false,
    this.showToCustomerCreditToggle = true,
    this.taxBreakdownEnabled = true,
    this.taxBreakdownUseBottomSheet = false,
  });

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

    final netTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;

    final deliveryCharge = computeDeliveryCharge(
      freeDeliveryEnabled:
          appSettingsProvider.appSettings?.freeDeliveryEnabled ?? false,
      freeDeliveryMinimumAmount: double.tryParse(
            appSettingsProvider.appSettings?.freeDeliveryMinimumAmount.trim() ??
                '',
          ) ??
          0.0,
      netTotal: netTotal,
      deliveryMethodId: billingProvider.deliveryMethodId,
      deliveryMethodName: billingProvider.deliveryMethod,
      deliveryMethods: deliveryMethodsProvider.deliveryMethods,
    );

    // Ensure priceSummary is computed
    localProductProvider.cartTotal;

    // Keep provider's total order amount in sync with cart total (only when
    // changed). The raw total drives discount remapping; the effective
    // (round-off adjusted) total drives payment validation, balance and
    // autofill — mirroring desktop `_getEffectiveOrderTotal()`.
    final orderTotal = netTotal + deliveryCharge;
    final effectiveOrderTotal = BillingTotals.effectiveOrderTotal(
      baseTotal: netTotal,
      deliveryCharge: deliveryCharge,
      priceRoundOff: appSettingsProvider.appSettings?.priceRoundOff == true,
    );
    if ((billingProvider.totalOrderAmount - orderTotal).abs() >= 0.001 ||
        (billingProvider.effectiveOrderTotal - effectiveOrderTotal).abs() >=
            0.001) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        billingProvider.setOrderTotals(
          totalOrderAmount: orderTotal,
          effectiveOrderTotal: effectiveOrderTotal,
        );
      });
    }

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          BuildPaymentRow(
            amount: "",
            title: 'billing.payment_summary'.tr,
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
            title: 'billing.net_amount'.tr,
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
                "$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)}",
            title: 'billing.discount'.tr,
            color: Colors.red,
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s15,
              0.18,
              Colors.red,
            ),
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s15,
              0.18,
              Colors.red,
            ),
          ),
          if (deliveryCharge > 0)
            BuildPaymentRow(
              amount: "$currency ${AmountHelper.formatAmount(deliveryCharge)}",
              title: 'billing.delivery_charge'.tr,
              color: Colors.green,
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                Colors.green,
              ),
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s15,
                0.18,
                Colors.green,
              ),
            ),
          const Divider(thickness: 2),
          BuildPaymentRow(
            amount:
                "$currency ${AmountHelper.roundOffAmount(localProductProvider.cartTotal + deliveryCharge)}",
            title: 'billing.total_payable_label'.tr,
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
      return AmountHelper.formatAmount(
          localProductProvider.cartTotal + deliveryCharge);
    }

    if (localProductProvider.priceSummary == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtotal row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'billing.subtotal'.tr,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              '$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Discount row (red text)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'billing.discount'.tr,
              style: const TextStyle(
                  fontSize: 14, color: Colors.red, fontWeight: FontWeight.w500),
            ),
            Text(
              '- $currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tax row (tappable for details on desktop when enabled)
        Builder(
          builder: (context) {
            final taxPercent =
                ((localProductProvider.priceSummary!.subTotal > 0)
                        ? (localProductProvider.priceSummary!.totalTax /
                            localProductProvider.priceSummary!.subTotal *
                            100)
                        : 15.0)
                    .toStringAsFixed(0);
            final taxRow = Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${'billing.tax'.tr} (VAT $taxPercent%)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                    decoration: taxBreakdownEnabled
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                ),
                Text(
                  '$currency ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            );
            if (!taxBreakdownEnabled) return taxRow;
            return GestureDetector(
              onTap: () {
                showTaxDetailsBreakdown(
                  context,
                  billingProvider.taxNames,
                  useBottomSheet: taxBreakdownUseBottomSheet,
                );
              },
              child: taxRow,
            );
          },
        ),
        const SizedBox(height: 10),

        // Delivery Charge row (green text)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'billing.delivery_charge'.tr,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              deliveryCharge == 0.0
                  ? 'billing.free'.tr
                  : '$currency ${AmountHelper.formatAmount(deliveryCharge)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // To Customer Credit toggle (only show when a customer is selected)
        if (showToCustomerCreditToggle &&
            billingProvider.selectedCustomer != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'billing.to_customer_credit'.tr,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0066CC)),
              ),
              Switch(
                value: billingProvider.toCustomerCreditEnabled,
                activeColor: const Color(0xFF3B82F6),
                onChanged: (value) {
                  billingProvider.setToCustomerCreditEnabled(value);
                  billingProvider.calculateBalance();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

        // Total Payable row (bold, primary blue)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'billing.total_payable_label'.tr,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0066CC)),
            ),
            Text(
              '$currency ${getFormattedTotal()}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0066CC)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Total Paid row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'billing.total_paid'.tr,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              '$currency ${AmountHelper.formatAmount(billingProvider.totalPaidAmount)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Balance row (green text)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'billing.balance'.tr,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              '$currency ${AmountHelper.formatAmount(billingProvider.balanceAmount)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
      ],
    );
  }
}
