import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/coupon_modal.dart';
import 'package:pos_machine/features/billing/presentation/widgets/delivery_method_modal.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_desktop_payment_controller.dart';

import 'package:pos_machine/features/billing/presentation/widgets/payment_method_modal.dart';

class PaymentCoordinator {
  const PaymentCoordinator._();

  static const _desktopPaymentController = BillingDesktopPaymentController();

  static void showPaymentMethodModal(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final masterData = Provider.of<MasterDataProvider>(context, listen: false);

    _desktopPaymentController.syncPaymentMethodIdsFromModels(
      bp,
      masterData.enabledSortedPaymentMethods,
    );

    String autoFillCashAmount = bp.cashAmountController.text;
    bool autoSelectCash = bp.isCashSelected;

    if (!bp.hasAnyPaymentSelected()) {
      autoFillCashAmount = localProductProvider.cartTotal.toStringAsFixed(2);
      autoSelectCash = true;
    }

    showDialog(
      context: context,
      builder: (context) => PaymentMethodModal(
        initialIsCashSelected: autoSelectCash,
        initialIsCardSelected: bp.isCardSelected,
        initialIsUpiSelected: bp.isUpiSelected,
        initialIsCodSelected: bp.isCodSelected,
        initialIsDebitSelected: bp.isDebitSelected,
        initialToCustomerCreditEnabled: bp.toCustomerCreditEnabled,
        initialCashAmount: autoFillCashAmount,
        initialCardAmount: bp.cardAmountController.text,
        initialUpiAmount: bp.upiAmountController.text,
        initialCodAmount: bp.codAmountController.text,
        initialDebitAmount: bp.debitAmountController.text,
        initialTransactionNumber: bp.transactionNumberController.text,
        initialExtraAmounts: bp.extraPaymentAmounts,
        cartTotal: localProductProvider.cartTotal,
        customerPrevBalance: bp.selectedCustomer?.balance ?? 0.0,
        onPaymentMethodSelected: (
          isCash,
          isCard,
          isUpi,
          isCod,
          isDebit,
          cashAmount,
          cardAmount,
          upiAmount,
          codAmount,
          debitAmount,
          transactionNumber,
          toCustomerCredit, {
          String? cashMethodId,
          String? cardMethodId,
          String? upiMethodId,
          String? codMethodId,
          Map<String, String>? extraMethodAmounts,
          Map<String, String>? extraMethodValues,
        }) {
          bp.updatePaymentFromModal(
            isCash: isCash,
            isCard: isCard,
            isUpi: isUpi,
            isCod: isCod,
            isDebit: isDebit,
            cashAmount: cashAmount,
            cardAmount: cardAmount,
            upiAmount: upiAmount,
            codAmount: codAmount,
            debitAmount: debitAmount,
            transactionNumber: transactionNumber,
            toCustomerCredit: toCustomerCredit,
            cashMethodId: cashMethodId,
            cardMethodId: cardMethodId,
            upiMethodId: upiMethodId,
            codMethodId: codMethodId,
            extraMethodAmounts: extraMethodAmounts,
            extraMethodValues: extraMethodValues,
          );
          // Recalculate balance with current cart total
          final netTotal =
              Provider.of<LocalProductProvider>(context, listen: false)
                      .priceSummary
                      ?.netTotal ??
                  0.0;
          Provider.of<BillingProvider>(context, listen: false)
              .setTotalOrderAmount(netTotal);
        },
      ),
    );
  }

  static void showDeliveryMethodModal(BuildContext context) {
    final bp = Provider.of<BillingProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => DeliveryMethodModal(
        initialDeliveryMethod: bp.deliveryMethod,
        initialDeliveryMethodId: bp.deliveryMethodId,
        initialCarNumber: bp.carNumberController.text,
        initialComment: bp.commentController.text,
        initialDeliveryDate: bp.deliveryDate?.toIso8601String(),
        initialDeliveryTime: bp.deliveryTime,
        onDeliveryMethodSelected: (
          method,
          methodId,
          carNumber,
          comment,
          selectedDate,
          selectedTime,
          address,
        ) {
          bp.setDeliveryMethod(method, methodId);
          bp.carNumberController.text = carNumber;
          bp.commentController.text = comment;
          bp.setDeliveryDateString(selectedDate);
          bp.setDeliveryTime(selectedTime);
        },
      ),
    );
  }

  static void showCouponModal(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final bp = Provider.of<BillingProvider>(context, listen: false);
    final currentDiscounts = localProductProvider.getCurrentDiscount();

    showDialog(
      context: context,
      builder: (context) => CouponModal(
        subTotal: localProductProvider.subTotalBeforeDiscount,
        initialFlatDiscount: currentDiscounts['flatDiscount'],
        initialPercentageDiscount: currentDiscounts['percentageDiscount'],
        initialCouponCode: bp.coupenCodeTextController.text,
        isCouponApplied: bp.isCouponApplied,
        onCouponAction: (
          couponCode,
          shouldApply, {
          double? flatDiscount,
          double? percentageDiscount,
        }) async {
          if (shouldApply) {
            Provider.of<BillingProvider>(context, listen: false)
                .coupenCodeTextController
                .text = couponCode;

            final localProductProvider =
                Provider.of<LocalProductProvider>(context, listen: false);
            localProductProvider.applyDiscount(
              flatDiscount: flatDiscount ?? 0.0,
              percentageDiscount: percentageDiscount ?? 0.0,
            );

            if (couponCode.isNotEmpty) {
              await applyCoupon(context);
            }

            Provider.of<BillingProvider>(context, listen: false)
                .setCouponApplied(true,
                    code: couponCode,
                    discount: flatDiscount ?? percentageDiscount ?? 0.0);
          } else {
            final localProductProvider =
                Provider.of<LocalProductProvider>(context, listen: false);
            localProductProvider.clearDiscount();

            Provider.of<BillingProvider>(context, listen: false)
                .clearDiscounts();
            // Refresh cart data after removing coupon
            String? accessToken =
                Provider.of<AuthModel>(context, listen: false).token;
            int? customerId =
                Provider.of<AuthModel>(context, listen: false).userId;

            if (customerId != null && accessToken != null) {
              Provider.of<CartProvider>(context, listen: false)
                  .fetchCartDataFromApi(
                customerId: customerId,
                accessToken: accessToken,
              );
            }
          }
        },
      ),
    );
  }

  static Future<void> applyCoupon(BuildContext context) async {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    double? totalAmount =
        Provider.of<LocalProductProvider>(context, listen: false)
            .priceSummary
            ?.netTotal;
    String couponCode = Provider.of<BillingProvider>(context, listen: false)
        .coupenCodeTextController
        .text;

    if (accessToken != null && totalAmount != null) {
      final result =
          await Provider.of<CartProvider>(context, listen: false).applyCoupon(
        totalAmount: totalAmount,
        couponCode: couponCode,
        accessToken: accessToken,
      );

      if (result != null) {
        if (result['success'] == true) {
          final couponData = result['data']['data'];
          double discountAmount =
              double.parse(couponData['discount_amount'].replaceAll(',', ''));
          double discountedTotal = totalAmount - discountAmount;

          Provider.of<CartProvider>(context, listen: false).updatePriceSummary(
            discountAmount: discountAmount,
            discountedTotal: discountedTotal,
          );

          Provider.of<BillingProvider>(context, listen: false)
              .setCouponApplied(true);

          showScaffold(
            context: context,
            message: result['message'] ?? 'Coupon Applied Successfully',
          );
        } else {
          showScaffoldError(
            context: context,
            message: result['message'] ?? 'Failed to Apply Coupon',
          );
        }
      } else {
        showScaffoldError(
          context: context,
          message: 'billing.error_occurred_try_again'.tr,
        );
      }
    } else {
      showScaffoldError(
        context: context,
        message: 'general.not_authenticated'.tr,
      );
    }
  }
}
