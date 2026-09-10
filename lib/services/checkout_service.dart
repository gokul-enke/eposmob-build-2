import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/domain/order_customer_fields.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
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

  /// Desktop confirm parity: a registered customer id, a typed phone, or the
  /// sales-executive default phone all satisfy the customer requirement.
  bool _hasCustomerForCheckout(BillingProvider billingProvider) {
    return billingProvider.selectedCustomerID != null ||
        (billingProvider.mobileNumberText?.trim().isNotEmpty ?? false) ||
        (billingProvider.salesExecutivemobileNumberText?.trim().isNotEmpty ??
            false);
  }

  String? _phoneForOrder(BillingProvider billingProvider) {
    return OrderCustomerFields.phoneForOrder(
      selectedPhone: billingProvider.selectedCustomerPhone,
      customerPhone: billingProvider.selectedCustomer?.phone,
      mobileNumberText: billingProvider.mobileNumberText,
      controllerText: billingProvider.mobileNumberTextController.text,
    );
  }

  String? _nameForOrder(BillingProvider billingProvider) {
    return OrderCustomerFields.nameForOrder(
      billingProvider.selectedCustomer?.name,
    );
  }

  bool _validateFinalCheckout({
    required BillingProvider billingProvider,
    required bool showErrors,
    required bool requirePaymentVisited,
  }) {
    if (!_hasCustomerForCheckout(billingProvider)) {
      if (showErrors) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectCustomer,
        );
      }
      return false;
    }

    if (!billingProvider.hasAnyPaymentSelected()) {
      if (showErrors) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectPaymentMethod,
        );
      }
      return false;
    }

    final ready =
        const BillingMobilePaymentController().validatePaymentReadyForConfirm(
      billingProvider,
      paymentStepVisited:
          requirePaymentVisited ? billingProvider.paymentStepVisited : true,
    );
    if (!ready.isValid) {
      if (showErrors) {
        showScaffoldError(
          context: context,
          message: ready.message ??
              BillingMobileErrorMessages.configurePaymentBeforeConfirm,
        );
      }
      return false;
    }

    if (!billingProvider.validateCarNumberIfNeeded()) {
      if (showErrors) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.enterCarNumber,
        );
      }
      return false;
    }

    return true;
  }

  /// Confirms the current order via the API. Returns `true` when the server
  /// accepted the order (an `order_id` was returned), so callers can run the
  /// post-confirm workspace reset (default-customer re-apply, etc.).
  Future<bool> confirmOrder() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.noInternetConfirm,
      );
      return false;
    }
    billingDebugCheckout('confirmOrder', 'started');

    bool orderConfirmed = false;
    // The spinner is raised before the subscription guard so the button always
    // reflects the tap; the guard runs inside the try so `finally` clears it on
    // every exit path.
    billingProvider.setLoadingConfirmOrder(true);
    final releaseCheckoutUi =
        OrderSubmissionCoordinator.instance.holdCheckoutUi();
    try {
      if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(
        context,
      )) {
        return false;
      }

      List<String> selectedPaymentMethods =
          billingProvider.getSelectedPaymentMethodsForApi();

      billingDebugCheckout(
        'confirmOrder',
        'validatingPayment',
        hasPayment: billingProvider.hasAnyPaymentSelected(),
      );

      if (!_validateFinalCheckout(
        billingProvider: billingProvider,
        showErrors: true,
        requirePaymentVisited: true,
      )) {
        billingDebugCheckout(
          'confirmOrder',
          'validationFailed',
          errorType: 'finalCheckout',
        );
        return false;
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
        return false;
      }

      // Desktop parity: do not block POS order throughput on local price/MRP
      // validation here. TODO: backend validation should reject invalid
      // price/MRP later without blocking mobile POS checkout.
      // final hasInvalidPricing = localProductProvider.cartItems.any((item) =>
      //     item.price == null ||
      //     item.price! < 0 ||
      //     item.mrp == null ||
      //     item.mrp! < 0);
      //
      // if (hasInvalidPricing) {
      //   showScaffoldError(
      //     context: context,
      //     message: BillingMobileErrorMessages.invalidPricingBeforeConfirm,
      //   );
      //   return false;
      // }

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

      await localProductProvider.flushPersistence();
      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        protectSubmission: true,
        localDraftId: localProductProvider.currentOrder?.id,
        cartSessionId: localProductProvider.cartSessionId,
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: billingProvider.transactionNumberController.text,
        totalPrice: orderTotal.toString(),
        customerId: billingProvider.selectedCustomerID,
        customerPhone: _phoneForOrder(billingProvider),
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
          .then((response) async {
        if (!context.mounted) return;
        if (await SubscriptionActionGuard.handleBackendResponse(
          context,
          response,
        )) {
          return;
        }
        billingDebugCheckout(
          'confirmOrder',
          response["order_id"] != null ? 'succeeded' : 'apiFailed',
        );
        if (response["order_id"] != null) {
          orderConfirmed = true;
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
          unawaited(Provider.of<CartProvider>(context, listen: false)
              .submissions
              .completeLocalCleanup(
                  response, localProductProvider.flushPersistence));

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
        message:
            'We couldn’t complete the checkout screen. Review the order status before billing again.',
      );
    } finally {
      releaseCheckoutUi();
      billingProvider.setLoadingConfirmOrder(false);
      billingDebugCheckout('confirmOrder', 'completed');
    }
    return orderConfirmed;
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
    final releaseCheckoutUi =
        OrderSubmissionCoordinator.instance.holdCheckoutUi();
    try {
      if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(
        context,
      )) {
        return null;
      }

      final selectedPaymentMethods =
          billingProvider.getSelectedPaymentMethodsForApi();

      billingDebugCheckout(
        'createOrderAndPrint',
        'validatingPayment',
        hasPayment: billingProvider.hasAnyPaymentSelected(),
      );

      if (!_validateFinalCheckout(
        billingProvider: billingProvider,
        showErrors: true,
        requirePaymentVisited: true,
      )) {
        billingDebugCheckout(
          'createOrderAndPrint',
          'validationFailed',
          errorType: 'finalCheckout',
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

      // Desktop parity: do not block POS order throughput on local price/MRP
      // validation here. TODO: backend validation should reject invalid
      // price/MRP later without blocking mobile POS checkout.
      // final hasInvalidPricing = localProductProvider.cartItems.any((item) =>
      //     item.price == null ||
      //     item.price! < 0 ||
      //     item.mrp == null ||
      //     item.mrp! < 0);
      // if (hasInvalidPricing) {
      //   showScaffoldError(
      //     context: context,
      //     message: BillingMobileErrorMessages.invalidPricingBeforeConfirm,
      //   );
      //   return null;
      // }

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

      await localProductProvider.flushPersistence();
      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        protectSubmission: true,
        localDraftId: localProductProvider.currentOrder?.id,
        cartSessionId: localProductProvider.cartSessionId,
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: billingProvider.transactionNumberController.text,
        totalPrice: orderTotal.toString(),
        customerId: billingProvider.selectedCustomerID,
        customerPhone: _phoneForOrder(billingProvider),
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
        if (!context.mounted) return;
        if (await SubscriptionActionGuard.handleBackendResponse(
          context,
          response,
        )) {
          return;
        }
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
          unawaited(Provider.of<CartProvider>(context, listen: false)
              .submissions
              .completeLocalCleanup(
                  response, localProductProvider.flushPersistence));

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

          // Match confirmOrder / desktop full reset: clear all payment method
          // selections, amounts, to-customer-credit and Pine Labs state so the
          // next sale starts from a clean workspace.
          billingProvider.clearAllPaymentMethods();
          billingProvider.setPineLabsPaymentSuccess(false);
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
        message:
            'We couldn’t complete the checkout screen. Review the order status before billing again.',
      );
    } finally {
      releaseCheckoutUi();
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

      final orderData = billingProvider.createOrderData();
      final paymentMethod = orderData['paymentMethod']?.toString() ?? "";
      final paidAmount = orderData['paidAmount']?.toString() ?? "0";

      final currentOrder = localProductProvider.currentOrder;
      final customerNameToSave = _nameForOrder(billingProvider);
      final customerPhoneToSave = _phoneForOrder(billingProvider);
      final customerTypeToSave = billingProvider.selectedCustomer?.customerType;
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
          customerType: customerTypeToSave,
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
          customerType: customerTypeToSave,
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
      if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(
        context,
      )) {
        return null;
      }

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: BillingMobileErrorMessages.emptyCart);
        return null;
      }

      if (!_validateFinalCheckout(
        billingProvider: billingProvider,
        showErrors: true,
        requirePaymentVisited: true,
      )) {
        return null;
      }

      final orderData = billingProvider.createOrderData();
      final paymentMethod = orderData['paymentMethod']?.toString() ?? "";
      final paidAmount = orderData['paidAmount']?.toString() ?? "0";

      SavedOrder? result;
      final currentOrder = localProductProvider.currentOrder;
      final customerNameToSave = _nameForOrder(billingProvider);
      final customerPhoneToSave = _phoneForOrder(billingProvider);
      final customerTypeToSave = billingProvider.selectedCustomer?.customerType;
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
          customerType: customerTypeToSave,
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
            customerType: customerTypeToSave,
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
          customerType: customerTypeToSave,
        );
        showScaffold(
          context: context,
          message: "Order saved to confirmed orders",
        );
      }

      localProductProvider.clearCartAfterOrder();

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
