import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Result of a [CheckoutService.saveOrder] call.
///
/// Having an explicit result type eliminates the ambiguity of the old `bool`
/// return where `false` meant BOTH "saved new order" and "save failed".
enum SaveOrderResult {
  /// A new draft order was created successfully.
  savedNew,

  /// An existing draft order was updated successfully.
  updatedExisting,

  /// Save was blocked by a validation error (empty cart, invalid price, etc.).
  /// The service has already shown an error snackbar; callers must NOT clear
  /// the workspace.
  validationFailed,

  /// Save failed due to an unexpected exception.
  /// The service has already shown an error snackbar; callers must NOT clear
  /// the workspace.
  failed,
}

class CheckoutService {
  final BuildContext context;
  const CheckoutService(this.context);

  Future<void> confirmOrder() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.noInternetConfirm,
      );
      return;
    }

    billingDebugCheckout('confirmOrder', 'started');

    billingProvider.setLoadingConfirmOrder(true);
    try {
      final skipCustomerSelection = Provider.of<AppSettingsProvider>(
            context,
            listen: false,
          ).appSettings?.skipCustomerSelection ??
          false;
      if (!skipCustomerSelection &&
          billingProvider.selectedCustomerID == null &&
          billingProvider.mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectCustomer,
        );
        return;
      }

      // Check if any payment method is selected (provider-level helper)
      List<String> selectedPaymentMethods =
          billingProvider.getSelectedPaymentMethodsForApi();

      billingDebugCheckout(
        'confirmOrder',
        'validatingPayment',
        hasPayment: billingProvider.hasAnyPaymentSelected(),
      );

      if (!billingProvider.hasAnyPaymentSelected()) {
        billingDebugCheckout('confirmOrder', 'validationFailed', errorType: 'noPayment');
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectPaymentMethod,
        );
        return;
      }

      if (!billingProvider.validateCarNumberIfNeeded()) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.enterCarNumber,
        );
        return;
      }

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      final provider = Provider.of<CartProvider>(context, listen: false);
      int? cartId = provider.getCartIDForOrder;

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.emptyCart,
        );
        return;
      }

      // Validate that all items have valid pricing before API call
      bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
          item.price == null ||
          item.price! < 0 ||
          item.mrp == null ||
          item.mrp! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.invalidPricingBeforeConfirm,
        );
        return;
      }

      final items = localProductProvider.buildOrderItemsPayload();
      final paidMethods =
          Provider.of<BillingProvider>(context, listen: false).getPaidMethods();

      billingDebugCheckout(
        'confirmOrder',
        'submitting',
        itemCount: items.length,
        hasCustomer: billingProvider.selectedCustomerID != null ||
            (billingProvider.mobileNumberText?.isNotEmpty ?? false),
        hasPayment: paidMethods.isNotEmpty,
      );

      final netTotal = localProductProvider.priceSummary!.netTotal;
      final deliveryCharge = resolveDeliveryCharge(context);
      final orderTotal = netTotal + deliveryCharge;

      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: billingProvider.transactionNumberController.text,
        totalPrice: orderTotal.toString(),
        customerId: billingProvider.selectedCustomerID,
        customerPhone: billingProvider.selectedCustomerPhone ??
            billingProvider.mobileNumberText,
        // Always use multi-payment format
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: selectedPaymentMethods,
        paidMethods: paidMethods,
        balanceAmount: Provider.of<BillingProvider>(context, listen: false)
            .balanceAmount
            .toString(),
        couponId:
            Provider.of<BillingProvider>(context, listen: false).isCouponApplied
                ? Provider.of<BillingProvider>(context, listen: false)
                    .coupenCodeTextController
                    .text
                : null,
        comment: billingProvider.commentController.text,
        deliveryMethodId: billingProvider.deliveryMethodId,
        carNumber: billingProvider.carNumberController.text,
        status: "confirmed",
        deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
        deliveryTime: billingProvider.deliveryTime,
        // Include discount data
        flatDiscount: localProductProvider.priceSummary!.flatDiscount,
        percentageDiscount:
            localProductProvider.priceSummary!.percentageDiscount,
        discountAmount: localProductProvider.priceSummary!.discount,
        toCustomerCredit: billingProvider.toCustomerCreditEnabled,
        address: billingProvider.orderAddress.isNotEmpty
            ? billingProvider.orderAddress
            : null,
        deliveryCharge: deliveryCharge,
      )
          .then((response) {
        billingDebugCheckout(
          'confirmOrder',
          response["order_id"] != null ? 'succeeded' : 'apiFailed',
        );
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "Order Confirmed Successfully",
          );

          final localProductProvider =
              Provider.of<LocalProductProvider>(context, listen: false);
          if (localProductProvider.currentOrder != null) {
            localProductProvider
                .deleteSavedOrder(localProductProvider.currentOrder!.id);
          }
          localProductProvider.clearCartAfterOrder();

          // Clear the mobile number after successful save
          billingProvider.setMobileNumberText("");
          billingProvider.clearSelectedCustomer();
          billingProvider.mobileNumberTextController.clear();
          billingProvider.clearProductFields();
          Provider.of<BillingProvider>(context, listen: false)
              .coupenCodeTextController
              .clear();
          billingProvider.transactionNumberController.clear();
          billingProvider.paidAmountController.clear();
          billingProvider.carNumberController.clear();
          billingProvider.commentController.clear();
          billingProvider.setDeliveryDate(null);
          billingProvider.setDeliveryTime(null);

          billingProvider.clearAllPaymentMethods();
          billingProvider.setPineLabsPaymentSuccess(false);

          // Notify UI hooks that depend on resets (optional)
        } else {
          showScaffoldError(
            context: context,
            message: BillingMobileErrorMessages.orderApiFailure(
              Map<dynamic, dynamic>.from(response as Map),
              fallback: BillingMobileErrorMessages.confirmOrderFailed,
            ),
          );
        }
      });
    } catch (error) {
      billingDebugCheckout(
        'confirmOrder',
        'exception',
        errorType: error.runtimeType.toString(),
      );
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.checkoutException(
          error,
          operation: 'confirm order',
        ),
      );
    } finally {
      billingProvider.setLoadingConfirmOrder(false);
      billingDebugCheckout('confirmOrder', 'completed');
    }
  }

  Future<String?> createOrderAndPrint() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.noInternetCreateOrder,
      );
      return null;
    }

    billingDebugCheckout('createOrderAndPrint', 'started');

    billingProvider.setLoadingCreateOrder(true);
    String? createdOrderNumber;
    try {
      final skipCustomerSelection = Provider.of<AppSettingsProvider>(
            context,
            listen: false,
          ).appSettings?.skipCustomerSelection ??
          false;
      if (!skipCustomerSelection &&
          billingProvider.selectedCustomerID == null &&
          billingProvider.mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectCustomer,
        );
        return null;
      }

      // Guard: require at least one payment method (provider-level helper)
      final selectedPaymentMethods =
          billingProvider.getSelectedPaymentMethodsForApi();

      billingDebugCheckout(
        'createOrderAndPrint',
        'validatingPayment',
        hasPayment: billingProvider.hasAnyPaymentSelected(),
      );

      if (!billingProvider.hasAnyPaymentSelected()) {
        billingDebugCheckout(
          'createOrderAndPrint',
          'validationFailed',
          errorType: 'noPayment',
        );
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectPaymentMethod,
        );
        return null;
      }

      // Car number required for car delivery
      if (!billingProvider.validateCarNumberIfNeeded()) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.enterCarNumber,
        );
        return null;
      }

      final accessToken = Provider.of<AuthModel>(context, listen: false).token;
      final provider = Provider.of<CartProvider>(context, listen: false);
      final cartId = provider.getCartIDForOrder;

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.emptyCart,
        );
        return null;
      }

      // Validate item pricing
      final hasInvalidPricing = localProductProvider.cartItems.any((item) =>
          item.price == null ||
          item.price! < 0 ||
          item.mrp == null ||
          item.mrp! < 0);
      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.invalidPricingBeforeConfirm,
        );
        return null;
      }

      final items = localProductProvider.buildOrderItemsPayload();

      final priceSummary = localProductProvider.priceSummary!;
      billingDebugCheckout(
        'createOrderAndPrint',
        'submitting',
        itemCount: items.length,
        hasCustomer: billingProvider.selectedCustomerID != null ||
            (billingProvider.mobileNumberText?.isNotEmpty ?? false),
        hasPayment: billingProvider.hasAnyPaymentSelected(),
      );

      final deliveryCharge = resolveDeliveryCharge(context);
      final orderTotal = priceSummary.netTotal + deliveryCharge;

      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: billingProvider.transactionNumberController.text,
        totalPrice: orderTotal.toString(),
        customerId: billingProvider.selectedCustomerID,
        customerPhone: billingProvider.selectedCustomerPhone ??
            billingProvider.mobileNumberText,
        // Always use multi-payment format
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: selectedPaymentMethods,
        paidMethods: Provider.of<BillingProvider>(context, listen: false)
            .getPaidMethods(),
        balanceAmount: Provider.of<BillingProvider>(context, listen: false)
            .balanceAmount
            .toString(),
        couponId:
            Provider.of<BillingProvider>(context, listen: false).isCouponApplied
                ? Provider.of<BillingProvider>(context, listen: false)
                    .coupenCodeTextController
                    .text
                : null,
        comment: billingProvider.commentController.text,
        deliveryMethodId: billingProvider.deliveryMethodId,
        carNumber: billingProvider.carNumberController.text,
        status: "confirmed",
        deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
        deliveryTime: billingProvider.deliveryTime,
        // Include discount data
        flatDiscount: priceSummary.flatDiscount,
        percentageDiscount: priceSummary.percentageDiscount,
        discountAmount: priceSummary.discount,
        toCustomerCredit: billingProvider.toCustomerCreditEnabled,
        address: billingProvider.orderAddress.isNotEmpty
            ? billingProvider.orderAddress
            : null,
        deliveryCharge: deliveryCharge,
      )
          .then((response) async {
        billingDebugCheckout(
          'createOrderAndPrint',
          response["order_id"] != null ? 'succeeded' : 'apiFailed',
        );
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "Order Saved Successfully",
          );

          if (localProductProvider.currentOrder != null) {
            localProductProvider
                .deleteSavedOrder(localProductProvider.currentOrder!.id);
          }
          localProductProvider.clearCartAfterOrder();

          try {
            createdOrderNumber = response["order_number"]?.toString();
          } catch (error) {
            billingDebugCheckout(
              'createOrderAndPrint',
              'printPrepFailed',
              errorType: error.runtimeType.toString(),
            );
          }

          // Reset provider state
          billingProvider.setMobileNumberText("");
          billingProvider.clearSelectedCustomer();
          billingProvider.mobileNumberTextController.clear();
          billingProvider.clearProductFields();
          Provider.of<BillingProvider>(context, listen: false)
              .coupenCodeTextController
              .clear();
          billingProvider.transactionNumberController.clear();
          billingProvider.paidAmountController.clear();
          billingProvider.carNumberController.clear();
          billingProvider.commentController.clear();
          billingProvider.setDeliveryDate(null);
          billingProvider.setDeliveryTime(null);
        } else {
          showScaffoldError(
            context: context,
            message: BillingMobileErrorMessages.orderApiFailure(
              Map<dynamic, dynamic>.from(response as Map),
              fallback: BillingMobileErrorMessages.createOrderFailed,
            ),
          );
        }
      });
    } catch (error) {
      billingDebugCheckout(
        'createOrderAndPrint',
        'exception',
        errorType: error.runtimeType.toString(),
      );
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.checkoutException(
          error,
          operation: 'create order',
        ),
      );
    } finally {
      billingProvider.setLoadingCreateOrder(false);
      billingDebugCheckout('createOrderAndPrint', 'completed');
    }
    return createdOrderNumber;
  }

  Future<SaveOrderResult> saveOrder() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    billingProvider.setLoadingSaveOrder(true);
    try {
      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: BillingMobileErrorMessages.emptyCart);
        return SaveOrderResult.validationFailed;
      }

      // Validate that all items have valid pricing
      final hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);
      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.invalidPricingBeforeSave,
        );
        return SaveOrderResult.validationFailed;
      }

      final orderData = billingProvider.createOrderData();
      final paymentMethod = orderData['paymentMethod']?.toString() ?? "";
      final paidAmount = orderData['paidAmount']?.toString() ?? "0";

      final currentOrder = localProductProvider.currentOrder;
      final customerNameToSave = billingProvider.selectedCustomer?.name;
      final customerPhoneToSave = billingProvider.selectedCustomerPhone ??
          billingProvider.mobileNumberText;
      final deliveryCharge = resolveDeliveryCharge(context);

      if (currentOrder != null) {
        // Update existing order
        localProductProvider.updateSavedOrder(
          currentOrder.id,
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: billingProvider.commentController.text,
          deliveryMethod: billingProvider.deliveryMethod,
          customerId: billingProvider.selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: billingProvider.balanceAmount.toString(),
          transactionId: billingProvider.transactionNumberController.text,
          couponId: billingProvider.isCouponApplied
              ? billingProvider.coupenCodeTextController.text
              : null,
          deliveryMethodId: billingProvider.deliveryMethodId,
          carNumber: billingProvider.carNumberController.text,
          context: context,
          status: "saved",
          deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
          deliveryTime: billingProvider.deliveryTime,
          toCustomerCredit: billingProvider.toCustomerCreditEnabled,
          address: billingProvider.orderAddress.isNotEmpty
              ? billingProvider.orderAddress
              : null,
          deliveryCharge: deliveryCharge,
        );
        showScaffold(context: context, message: "Order Updated Successfully");
        return SaveOrderResult.updatedExisting;
      } else {
        // Save as new order
        localProductProvider.saveCurrentCartAsOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: billingProvider.commentController.text,
          deliveryMethod: billingProvider.deliveryMethod,
          customerId: billingProvider.selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: billingProvider.balanceAmount.toString(),
          transactionId: billingProvider.transactionNumberController.text,
          couponId: billingProvider.isCouponApplied
              ? billingProvider.coupenCodeTextController.text
              : null,
          deliveryMethodId: billingProvider.deliveryMethodId,
          carNumber: billingProvider.carNumberController.text,
          status: "saved",
          deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
          deliveryTime: billingProvider.deliveryTime,
          context: context,
          toCustomerCredit: billingProvider.toCustomerCreditEnabled,
          address: billingProvider.orderAddress.isNotEmpty
              ? billingProvider.orderAddress
              : null,
          deliveryCharge: deliveryCharge,
        );
        showScaffold(context: context, message: "Order Saved Successfully");
        return SaveOrderResult.savedNew;
      }
    } catch (e) {
      billingDebugCheckout(
        'saveOrder',
        'exception',
        errorType: e.runtimeType.toString(),
      );
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.saveOrderFailed,
      );
      return SaveOrderResult.failed;
    } finally {
      billingProvider.setLoadingSaveOrder(false);
    }
  }

  Future<SavedOrder?> saveOrderAndReturnConfirmed() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    billingProvider.setLoadingSaveOrderAndPrint(true);
    try {
      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: BillingMobileErrorMessages.emptyCart);
        return null;
      }

      // Validate that all items have valid pricing
      final hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);
      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.invalidPricingBeforeSave,
        );
        return null;
      }

      final orderData = billingProvider.createOrderData();
      final paymentMethod = orderData['paymentMethod']?.toString() ?? "";
      final paidAmount = orderData['paidAmount']?.toString() ?? "0";

      SavedOrder? result;
      final currentOrder = localProductProvider.currentOrder;
      final customerNameToSave = billingProvider.selectedCustomer?.name;
      final customerPhoneToSave = billingProvider.selectedCustomerPhone ??
          billingProvider.mobileNumberText;
      final deliveryCharge = resolveDeliveryCharge(context);

      if (currentOrder != null) {
        final currentOrderId = currentOrder.id;
        localProductProvider.updateSavedOrder(
          currentOrderId,
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: billingProvider.commentController.text,
          deliveryMethod: billingProvider.deliveryMethod,
          customerId: billingProvider.selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: billingProvider.balanceAmount.toString(),
          transactionId: billingProvider.transactionNumberController.text,
          couponId: billingProvider.isCouponApplied
              ? billingProvider.coupenCodeTextController.text
              : null,
          deliveryMethodId: billingProvider.deliveryMethodId,
          carNumber: billingProvider.carNumberController.text,
          status: "confirmed",
          deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
          deliveryTime: billingProvider.deliveryTime,
          toCustomerCredit: billingProvider.toCustomerCreditEnabled,
          context: context,
          address: billingProvider.orderAddress.isNotEmpty
              ? billingProvider.orderAddress
              : null,
          deliveryCharge: deliveryCharge,
        );
        result = localProductProvider.moveToConfirmedOrders(currentOrderId);
        if (result != null) {
          showScaffold(
            context: context,
            message: "Order moved to confirmed orders",
          );
        } else {
          // Fallback: create a new confirmed order
          result = localProductProvider.saveCurrentCartAsConfirmedOrder(
            customerName: customerNameToSave,
            customerPhone: customerPhoneToSave,
            comment: billingProvider.commentController.text,
            deliveryMethod: billingProvider.deliveryMethod,
            customerId: billingProvider.selectedCustomerID,
            paymentMethod: paymentMethod,
            paidAmount: paidAmount,
            balanceAmount: billingProvider.balanceAmount.toString(),
            transactionId: billingProvider.transactionNumberController.text,
            couponId: billingProvider.isCouponApplied
                ? billingProvider.coupenCodeTextController.text
                : null,
            deliveryMethodId: billingProvider.deliveryMethodId,
            carNumber: billingProvider.carNumberController.text,
            status: "confirmed",
            deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
            deliveryTime: billingProvider.deliveryTime,
            toCustomerCredit: billingProvider.toCustomerCreditEnabled,
            context: context,
            address: billingProvider.orderAddress.isNotEmpty
                ? billingProvider.orderAddress
                : null,
            deliveryCharge: deliveryCharge,
          );
          showScaffold(
            context: context,
            message: "Order saved to confirmed orders",
          );
        }
      } else {
        result = localProductProvider.saveCurrentCartAsConfirmedOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: billingProvider.commentController.text,
          deliveryMethod: billingProvider.deliveryMethod,
          customerId: billingProvider.selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: billingProvider.balanceAmount.toString(),
          transactionId: billingProvider.transactionNumberController.text,
          couponId: billingProvider.isCouponApplied
              ? billingProvider.coupenCodeTextController.text
              : null,
          deliveryMethodId: billingProvider.deliveryMethodId,
          carNumber: billingProvider.carNumberController.text,
          status: "confirmed",
          deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
          deliveryTime: billingProvider.deliveryTime,
          toCustomerCredit: billingProvider.toCustomerCreditEnabled,
          context: context,
          address: billingProvider.orderAddress.isNotEmpty
              ? billingProvider.orderAddress
              : null,
          deliveryCharge: deliveryCharge,
        );
        showScaffold(
          context: context,
          message: "Order saved to confirmed orders",
        );
      }

      if (result != null) {
        localProductProvider.clearCartAfterOrder();
      }

      return result;
    } catch (e) {
      billingDebugCheckout(
        'saveOrderAndReturnConfirmed',
        'exception',
        errorType: e.runtimeType.toString(),
      );
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.saveOrderFailed,
      );
      return null;
    } finally {
      billingProvider.setLoadingSaveOrderAndPrint(false);
    }
  }
}
