import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class CheckoutService {
  final BuildContext context;
  const CheckoutService(this.context);

  Future<void> confirmOrder() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: "No internet connection. Cannot confirm order online.",
      );
      return;
    }

    debugPrint("Confirm Order pressed");
    debugPrint("🚀 API REQUEST STARTING - Confirm Order");

    billingProvider.setLoadingConfirmOrder(true);
    try {
      if (billingProvider.selectedCustomerID == null &&
          billingProvider.mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "Please select a customer",
        );
        return;
      }

      // Check if any payment method is selected (provider-level helper)
      List<String> selectedPaymentMethods =
          Provider.of<BillingProvider>(context, listen: false)
              .getSelectedPaymentMethodsExcludingEmpty();

      debugPrint('🔍 [CheckoutService] Validating payment methods...');
      debugPrint(
          '🔍 [CheckoutService] Selected methods (excluding empty): $selectedPaymentMethods');
      debugPrint(
          '🔍 [CheckoutService] hasAnyPaymentSelected: ${billingProvider.hasAnyPaymentSelected()}');
      debugPrint(
          '🔍 [CheckoutService] isOnlineSelected: ${billingProvider.isOnlineSelected}');

      if (!billingProvider.hasAnyPaymentSelected()) {
        debugPrint(
            '❌ [CheckoutService] No payment method selected - showing error');
        showScaffoldError(
          context: context,
          message: "Please select a payment method",
        );
        return;
      }

      debugPrint('✅ [CheckoutService] Payment method validation passed');

      if (!billingProvider.validateCarNumberIfNeeded()) {
        showScaffoldError(
          context: context,
          message: "Please enter Car Number",
        );
        return;
      }

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      final provider = Provider.of<CartProvider>(context, listen: false);
      int? cartId = provider.getCartIDForOrder;
      debugPrint("📦 Cart ID for order: $cartId");

      String paymentMethod = "";
      if (selectedPaymentMethods.contains("CASH")) {
        paymentMethod = "CASH";
      } else if (selectedPaymentMethods.contains("CARD")) {
        paymentMethod = "CARD";
      } else if (selectedPaymentMethods.contains("UPI")) {
        paymentMethod = "UPI";
      } else if (selectedPaymentMethods.contains("ONLINE")) {
        paymentMethod = "ONLINE";
      } else if (selectedPaymentMethods.contains("DEBIT")) {
        paymentMethod = "DEBIT";
      } else if (selectedPaymentMethods.contains("BALANCE")) {
        paymentMethod = "BALANCE";
      }
      debugPrint("💰 Payment Method: $paymentMethod");

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "Please add items to cart",
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
          message:
              "Please ensure all items have valid prices and MRP before confirming order",
        );
        return;
      }

      List<Map<String, dynamic>> items = [];
      for (var item in localProductProvider.cartItems) {
        debugPrint("📦 Order Item: ${item.product.productName}");
        debugPrint("  - Product ID: ${item.product.productId}");
        debugPrint("  - Quantity: ${item.quantity}");
        debugPrint("  - Custom Price: ${item.price}");
        debugPrint("  - Custom MRP: ${item.mrp}");
        debugPrint("  - Stock ID: ${item.selectedStock?.id}");

        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
          'mrp': item.mrp,
          'stock_id': item.selectedStock?.id,
        });
      }

      debugPrint("📋 Order Items: ${items.length} products");
      debugPrint(
          "💵 Total Price: ${localProductProvider.priceSummary!.netTotal}");
      debugPrint("👤 Customer ID: ${billingProvider.selectedCustomerID}");
      debugPrint(
          "📱 Customer Phone: ${billingProvider.selectedCustomerPhone ?? billingProvider.mobileNumberText}");
      debugPrint(
          "💳 Payment Details - Paid: ${billingProvider.paidAmountController.text}, Balance: ${Provider.of<BillingProvider>(context, listen: false).balanceAmount}");
      debugPrint(
          "🚚 Delivery Method: ${billingProvider.deliveryMethod} (ID: ${billingProvider.deliveryMethodId})");

      final paidMethods =
          Provider.of<BillingProvider>(context, listen: false).getPaidMethods();
      debugPrint("💰 [ConfirmOrder] Payment Methods: $selectedPaymentMethods");
      debugPrint("💰 [ConfirmOrder] Paid Methods (with amounts): $paidMethods");

      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: billingProvider.transactionNumberController.text,
        totalPrice: localProductProvider.priceSummary!.netTotal.toString(),
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
      )
          .then((response) {
        debugPrint("✅ API RESPONSE - Confirm Order: ${json.encode(response)}");
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
          localProductProvider.clearCart();

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

          // Clear all payment methods including Pine Labs ONLINE
          debugPrint(
              '🔄 [CheckoutService] Clearing all payment methods after order confirmation');
          billingProvider.clearAllPaymentMethods();
          billingProvider.setPineLabsPaymentSuccess(false);

          // Notify UI hooks that depend on resets (optional)
        } else {
          debugPrint("❌ API ERROR - Confirm Order failed");
          showScaffoldError(
            context: context,
            message: "Failed to Confirm Order",
          );
        }
      });
    } catch (error) {
      debugPrint("❌ EXCEPTION in confirmOrder: $error");
    } finally {
      billingProvider.setLoadingConfirmOrder(false);
      debugPrint("🏁 Confirm Order process completed");
    }
  }

  Future<String?> createOrderAndPrint() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (!billingProvider.hasInternet) {
      showScaffoldError(
        context: context,
        message: "No internet connection. Cannot create order online.",
      );
      return null;
    }

    debugPrint("Create Order and Print pressed");
    debugPrint("🚀 API REQUEST STARTING - Create Order and Print");

    billingProvider.setLoadingCreateOrder(true);
    String? createdOrderNumber;
    try {
      if (billingProvider.selectedCustomerID == null &&
          billingProvider.mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "Please select a customer",
        );
        return null;
      }

      // Guard: require at least one payment method (provider-level helper)
      final selectedPaymentMethods =
          billingProvider.getSelectedPaymentMethodsExcludingEmpty();

      debugPrint('🔍 [CreateOrderAndPrint] Validating payment methods...');
      debugPrint(
          '🔍 [CreateOrderAndPrint] Selected methods: $selectedPaymentMethods');
      debugPrint(
          '🔍 [CreateOrderAndPrint] hasAnyPaymentSelected: ${billingProvider.hasAnyPaymentSelected()}');
      debugPrint(
          '🔍 [CreateOrderAndPrint] isOnlineSelected: ${billingProvider.isOnlineSelected}');

      if (!billingProvider.hasAnyPaymentSelected()) {
        debugPrint(
            '❌ [CreateOrderAndPrint] No payment method selected - showing error');
        showScaffoldError(
          context: context,
          message: "Please select a payment method",
        );
        return null;
      }

      // Car number required for car delivery
      if (!billingProvider.validateCarNumberIfNeeded()) {
        showScaffoldError(
          context: context,
          message: "Please enter Car Number",
        );
        return null;
      }

      final accessToken = Provider.of<AuthModel>(context, listen: false).token;
      final provider = Provider.of<CartProvider>(context, listen: false);
      final cartId = provider.getCartIDForOrder;
      debugPrint("📦 Cart ID for order: $cartId");

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: "Please add items to cart",
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
          message:
              "Please ensure all items have valid prices and MRP before confirming order",
        );
        return null;
      }

      // Build items
      final items = <Map<String, dynamic>>[];
      for (var item in localProductProvider.cartItems) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
          'mrp': item.mrp,
          'stock_id': item.selectedStock?.id,
        });
      }

      final priceSummary = localProductProvider.priceSummary!;

      await Provider.of<CartProvider>(context, listen: false)
          .addToOrderAPI(
        items: items,
        cartIds: cartId ?? 0,
        accessToken: accessToken ?? "",
        transactionId: billingProvider.transactionNumberController.text,
        totalPrice: priceSummary.netTotal.toString(),
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
      )
          .then((response) async {
        debugPrint(
            "✅ API RESPONSE - Create Order and Print: ${json.encode(response)}");
        if (response["order_id"] != null) {
          showScaffold(
            context: context,
            message: "Order Saved Successfully",
          );

          if (localProductProvider.currentOrder != null) {
            localProductProvider
                .deleteSavedOrder(localProductProvider.currentOrder!.id);
          }
          localProductProvider.clearCart();

          try {
            createdOrderNumber = response["order_number"]?.toString();
          } catch (error) {
            debugPrint("❌ Error preparing order details for print: $error");
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
          debugPrint("❌ API ERROR - Create Order and Print failed");
          showScaffoldError(
            context: context,
            message: "Failed to Save Order",
          );
        }
      });
    } catch (error) {
      debugPrint("❌ EXCEPTION in createOrderAndPrint: $error");
    } finally {
      billingProvider.setLoadingCreateOrder(false);
      debugPrint("🏁 Create Order and Print process completed");
    }
    return createdOrderNumber;
  }

  Future<bool> saveOrder() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    billingProvider.setLoadingSaveOrder(true);
    try {
      if (localProductProvider.cartItems.isEmpty) {
        showScaffoldError(
            context: context, message: "Please add items to cart");
        return false;
      }

      // Validate that all items have valid pricing
      final hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);
      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: "Please ensure all items have valid prices before saving",
        );
        return false;
      }

      // Determine paymentMethod string and paidAmount using multi-payment logic
      final methods = billingProvider.getSelectedPaymentMethodsExcludingEmpty();
      String paymentMethod = "";
      String paidAmount = "0";
      if (methods.length > 1) {
        final multiPaymentData = {
          "methods": methods,
          "amounts": {
            "CASH": billingProvider.cashAmountController.text.isNotEmpty
                ? billingProvider.cashAmountController.text
                : "0",
            "CARD": billingProvider.cardAmountController.text.isNotEmpty
                ? billingProvider.cardAmountController.text
                : "0",
            "UPI": billingProvider.upiAmountController.text.isNotEmpty
                ? billingProvider.upiAmountController.text
                : "0",
            "DEBIT": billingProvider.debitAmountController.text.isNotEmpty
                ? billingProvider.debitAmountController.text
                : "0",
          },
          "isMultiPayment": true
        };
        paymentMethod = json.encode(multiPaymentData);
        paidAmount = billingProvider.getTotalPaidAmount().toString();
      } else if (methods.isNotEmpty) {
        final m = methods.first;
        paymentMethod = m;
        if (m == "CASH") {
          paidAmount = billingProvider.cashAmountController.text;
        } else if (m == "CARD") {
          paidAmount = billingProvider.cardAmountController.text;
        } else if (m == "UPI") {
          paidAmount = billingProvider.upiAmountController.text;
        } else if (m == "DEBIT") {
          paidAmount = billingProvider.debitAmountController.text;
        } else {
          paidAmount = "0";
        }
      }

      final currentOrder = localProductProvider.currentOrder;
      final customerNameToSave = billingProvider.selectedCustomer?.name;
      final customerPhoneToSave = billingProvider.selectedCustomerPhone ??
          billingProvider.mobileNumberText;

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
          status: "saved",
          deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
          deliveryTime: billingProvider.deliveryTime,
          toCustomerCredit: billingProvider.toCustomerCreditEnabled,
        );
        showScaffold(context: context, message: "Order Updated Successfully");
        return true; // updated
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
        );
        showScaffold(context: context, message: "Order Saved Successfully");
        return false; // new save
      }
    } catch (e) {
      debugPrint("Error saving order: $e");
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
      return false;
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
            context: context, message: "Please add items to cart");
        return null;
      }

      // Validate that all items have valid pricing
      final hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);
      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: "Please ensure all items have valid prices before saving",
        );
        return null;
      }

      // Determine paymentMethod string and paidAmount using multi-payment logic
      final methods = billingProvider.getSelectedPaymentMethodsExcludingEmpty();
      String paymentMethod = "";
      String paidAmount = "0";
      if (methods.length > 1) {
        final multiPaymentData = {
          "methods": methods,
          "amounts": {
            "CASH": billingProvider.cashAmountController.text.isNotEmpty
                ? billingProvider.cashAmountController.text
                : "0",
            "CARD": billingProvider.cardAmountController.text.isNotEmpty
                ? billingProvider.cardAmountController.text
                : "0",
            "UPI": billingProvider.upiAmountController.text.isNotEmpty
                ? billingProvider.upiAmountController.text
                : "0",
            "DEBIT": billingProvider.debitAmountController.text.isNotEmpty
                ? billingProvider.debitAmountController.text
                : "0",
          },
          "isMultiPayment": true
        };
        paymentMethod = json.encode(multiPaymentData);
        paidAmount = billingProvider.getTotalPaidAmount().toString();
      } else if (methods.isNotEmpty) {
        final m = methods.first;
        paymentMethod = m;
        if (m == "CASH") {
          paidAmount = billingProvider.cashAmountController.text;
        } else if (m == "CARD") {
          paidAmount = billingProvider.cardAmountController.text;
        } else if (m == "UPI") {
          paidAmount = billingProvider.upiAmountController.text;
        } else if (m == "DEBIT") {
          paidAmount = billingProvider.debitAmountController.text;
        } else {
          paidAmount = "0";
        }
      }

      SavedOrder? result;
      final currentOrder = localProductProvider.currentOrder;
      final customerNameToSave = billingProvider.selectedCustomer?.name;
      final customerPhoneToSave = billingProvider.selectedCustomerPhone ??
          billingProvider.mobileNumberText;

      if (currentOrder != null) {
        result = localProductProvider.moveToConfirmedOrders(currentOrder.id);
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
        );
        showScaffold(
          context: context,
          message: "Order saved to confirmed orders",
        );
      }

      return result;
    } catch (e) {
      debugPrint(e.toString());
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
      return null;
    } finally {
      billingProvider.setLoadingSaveOrderAndPrint(false);
    }
  }
}
