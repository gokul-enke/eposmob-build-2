import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/domain/order_customer_fields.dart';
import 'package:pos_machine/features/billing/domain/receipt_customer_balance.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/models/delivery_method_registry.dart';
import 'package:pos_machine/services/local_first_sale_coordinator.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:pos_machine/services/print_service.dart';

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

    final ecommerceEnabled =
        Provider.of<AppSettingsProvider>(context, listen: false)
            .ecommerceEnabled;
    if (ecommerceEnabled &&
        DeliveryMethodRegistry.requiresAddress(
          billingProvider.deliveryMethod,
        ) &&
        billingProvider.orderPincode.trim().isEmpty) {
      if (showErrors) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.enterDeliveryPincode,
        );
      }
      return false;
    }

    return true;
  }

  OrderSubmissionPayload _buildConfirmedSalePayload(
    BillingProvider billingProvider,
    LocalProductProvider localProducts,
  ) {
    final priceSummary = localProducts.priceSummary!;
    final storeId = Provider.of<StoreSessionProvider>(context, listen: false)
        .activeStore
        ?.storeId;
    return OrderSubmissionPayload(
      items: localProducts.buildOrderItemsPayload(),
      customerId: billingProvider.selectedCustomerID,
      customerPhone: _phoneForOrder(billingProvider),
      transactionNumber: billingProvider.transactionNumberController.text,
      paymentMethods: billingProvider.getSelectedPaymentMethodsForApi(),
      paidMethods: billingProvider.getPaidMethods(),
      balanceAmount: billingProvider.balanceAmount.toString(),
      couponId: billingProvider.isCouponApplied &&
              billingProvider.coupenCodeTextController.text.trim().isNotEmpty
          ? billingProvider.coupenCodeTextController.text.trim()
          : null,
      comment: billingProvider.commentController.text.trim().isNotEmpty
          ? billingProvider.commentController.text.trim()
          : null,
      deliveryMethodId: billingProvider.deliveryMethodId.isNotEmpty
          ? billingProvider.deliveryMethodId
          : null,
      carNumber: billingProvider.carNumberController.text.trim().isNotEmpty
          ? billingProvider.carNumberController.text.trim()
          : null,
      status: 'confirmed',
      deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
      deliveryTime: billingProvider.deliveryTime,
      flatDiscount: priceSummary.flatDiscount,
      percentageDiscount: priceSummary.percentageDiscount,
      discountAmount: priceSummary.discount,
      toCustomerCredit: billingProvider.toCustomerCreditEnabled,
      creditSaleAmount: billingProvider.creditSaleAmount,
      address: billingProvider.orderAddress.trim().isNotEmpty
          ? billingProvider.orderAddress.trim()
          : null,
      addressId: billingProvider.orderAddressId,
      pincode: billingProvider.orderPincode,
      quotationId: localProducts.currentOrder?.quotationId,
      deliveryCharge: resolveDeliveryCharge(context),
      storeId: storeId,
    );
  }

  String? _selectedCustomerKyc(
    BillingProvider billingProvider,
    Set<String> acceptedKeys,
  ) {
    for (final item in billingProvider.selectedCustomer?.kyc ?? const []) {
      final key = item.key?.trim().toUpperCase().replaceAll('_', ' ');
      final value = item.value?.trim();
      if (key != null &&
          acceptedKeys.contains(key) &&
          value != null &&
          value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  SavedOrder _persistConfirmedSale(
    BillingProvider billingProvider,
    LocalProductProvider localProducts,
  ) {
    final orderData = billingProvider.createOrderData();
    return localProducts.saveCurrentCartAsConfirmedOrder(
      customerName: _nameForOrder(billingProvider),
      customerPhone: _phoneForOrder(billingProvider),
      comment: billingProvider.commentController.text,
      deliveryMethod: billingProvider.deliveryMethod,
      customerId: billingProvider.selectedCustomerID,
      paymentMethod: orderData['paymentMethod']?.toString() ?? '',
      paidAmount: orderData['paidAmount']?.toString() ?? '0',
      balanceAmount: billingProvider.balanceAmount.toString(),
      transactionId: billingProvider.transactionNumberController.text,
      couponId: billingProvider.isCouponApplied
          ? billingProvider.coupenCodeTextController.text.trim()
          : null,
      deliveryMethodId: billingProvider.deliveryMethodId,
      carNumber: billingProvider.carNumberController.text,
      status: 'confirmed',
      deliveryDate: billingProvider.deliveryDate?.toIso8601String(),
      deliveryTime: billingProvider.deliveryTime,
      toCustomerCredit: billingProvider.toCustomerCreditEnabled,
      context: context,
      alternatePhone: billingProvider.selectedCustomer?.altPhone,
      address: billingProvider.orderAddress.trim().isNotEmpty
          ? billingProvider.orderAddress.trim()
          : null,
      addressId: billingProvider.orderAddressId,
      pincode: billingProvider.orderPincode,
      deliveryCharge: resolveDeliveryCharge(context),
      customerVatNumber:
          _selectedCustomerKyc(billingProvider, const {'VAT', 'VAT NUMBER'}),
      customerCrNumber: _selectedCustomerKyc(
        billingProvider,
        const {'CR', 'CR NUMBER', 'COMMERCIAL REGISTRATION'},
      ),
      customerType: billingProvider.selectedCustomer?.customerType,
      quotationId: localProducts.currentOrder?.quotationId,
      quotationNumber: localProducts.currentOrder?.quotationNumber,
    );
  }

  void _resetConfirmedCheckoutState(BillingProvider billingProvider) {
    billingProvider.setMobileNumberText('');
    billingProvider.clearSelectedCustomer();
    billingProvider.mobileNumberTextController.clear();
    billingProvider.clearProductFields();
    billingProvider.coupenCodeTextController.clear();
    billingProvider.transactionNumberController.clear();
    billingProvider.paidAmountController.clear();
    billingProvider.carNumberController.clear();
    billingProvider.commentController.clear();
    billingProvider.setDeliveryDate(null);
    billingProvider.setDeliveryTime(null);
    billingProvider.setOrderAddress('');
    billingProvider.setOrderAddressDetails();
    billingProvider.clearAllPaymentMethods();
    billingProvider.setPineLabsPaymentSuccess(false);
  }

  Future<LocalFirstSaleResult<SavedOrder>?> _confirmLocalFirst({
    required bool printReceipt,
  }) async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProducts =
        Provider.of<LocalProductProvider>(context, listen: false);

    if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(context)) {
      return null;
    }
    if (!_validateFinalCheckout(
      billingProvider: billingProvider,
      showErrors: true,
      requirePaymentVisited: true,
    )) {
      return null;
    }
    if (localProducts.cartItems.isEmpty) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.emptyCart,
      );
      return null;
    }

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    final customers = Provider.of<CustomerProvider>(context, listen: false);
    final payload = _buildConfirmedSalePayload(billingProvider, localProducts);
    final previousDraftId = localProducts.currentOrder?.id;
    final sourceCartSessionId = localProducts.cartSessionId;
    final customer = billingProvider.selectedCustomer;
    final configuredDefaultPhone =
        Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings
                ?.autoAssignDefaultCustomerPhone
                .trim() ??
            '';
    final orderPhone = _phoneForOrder(billingProvider)?.trim() ?? '';
    final isDefaultCustomer = configuredDefaultPhone.isNotEmpty &&
        configuredDefaultPhone == orderPhone;
    final receiptBalance = ReceiptCustomerBalance.compute(
      isDefaultCustomer: isDefaultCustomer,
      customerBalance: customer?.balance,
      cartTotal:
          localProducts.priceSummary!.netTotal + resolveDeliveryCharge(context),
      totalPaid: billingProvider.getTotalPaidAmount(),
    );

    final result = await LocalFirstSaleCoordinator(
      LocalSaleSyncService.instance,
    ).confirm<SavedOrder>(
      surface: LocalSaleSurface.mobileBilling,
      sourceCartSessionId: sourceCartSessionId,
      payload: payload,
      accessToken: accessToken,
      persistLocalSale: () {
        final sale = _persistConfirmedSale(billingProvider, localProducts);
        return LocalSaleIdentity(
          value: sale,
          localOrderId: sale.id,
          localOrderNumber: sale.orderNumber,
        );
      },
      flushLocalPersistence: localProducts.flushPersistence,
      rollbackLocalSale: (sale) => localProducts.deleteConfirmedOrder(sale.id),
      commitLocalWorkspace: (_) {
        if (previousDraftId != null) {
          localProducts.deleteSavedOrder(previousDraftId);
        }
        localProducts.clearCartAfterOrder();
        localProducts.clearCurrentOrder();
        _resetConfirmedCheckoutState(billingProvider);
      },
      printLocalReceipt: printReceipt
          ? (sale) async {
              final printed = await const PrintService().printSavedOrder(
                context,
                sale,
                customerOldBalance: receiptBalance.oldBalance,
                customerCurrentBalance: receiptBalance.currentBalance,
              );
              if (!printed) {
                throw StateError('The local receipt could not be printed.');
              }
            }
          : null,
      onSyncFinished: (record) async {
        if (record.state != LocalSaleSyncState.synced || accessToken.isEmpty) {
          return;
        }
        try {
          await customers.fetchCustomers(
            accessToken: accessToken,
            listAll: true,
          );
          final refreshed = customers.allCustomers;
          if (refreshed != null && refreshed.isNotEmpty) {
            billingProvider.setCustomerList(List.of(refreshed));
          }
        } catch (_) {
          // Customer balance/cache refresh is best effort after a synced sale.
        }
      },
    );

    if (context.mounted) {
      showScaffold(
        context: context,
        message:
            'Order confirmed locally. Server sync continues in the background.',
      );
    }
    return result;
  }

  /// Returns true once the sale is durable locally. Server sync is observable
  /// separately in Sales → Confirmed Orders.
  Future<bool> confirmOrder() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.setLoadingConfirmOrder(true);
    billingDebugCheckout('confirmOrder', 'started');
    try {
      return await _confirmLocalFirst(printReceipt: false) != null;
    } catch (error) {
      billingDebugCheckout(
        'confirmOrder',
        'exception',
        errorType: error.runtimeType.toString(),
      );
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'The order could not be saved locally. Nothing was sent.',
        );
      }
      return false;
    } finally {
      billingProvider.setLoadingConfirmOrder(false);
      billingDebugCheckout('confirmOrder', 'completed');
    }
  }

  Future<LocalFirstSaleResult<SavedOrder>?> createOrderAndPrint() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.setLoadingCreateOrder(true);
    billingDebugCheckout('createOrderAndPrint', 'started');
    try {
      return await _confirmLocalFirst(printReceipt: true);
    } catch (error) {
      billingDebugCheckout(
        'createOrderAndPrint',
        'exception',
        errorType: error.runtimeType.toString(),
      );
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'The order could not be saved locally. Nothing was sent.',
        );
      }
      return null;
    } finally {
      billingProvider.setLoadingCreateOrder(false);
      billingDebugCheckout('createOrderAndPrint', 'completed');
    }
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
          addressId: billingProvider.orderAddressId,
          pincode: billingProvider.orderPincode,
          deliveryCharge: deliveryCharge,
          customerType: customerTypeToSave,
          quotationId: currentOrder.quotationId,
          quotationNumber: currentOrder.quotationNumber,
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
          addressId: billingProvider.orderAddressId,
          pincode: billingProvider.orderPincode,
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
          addressId: billingProvider.orderAddressId,
          pincode: billingProvider.orderPincode,
          deliveryCharge: deliveryCharge,
          customerType: customerTypeToSave,
          quotationId: currentOrder.quotationId,
          quotationNumber: currentOrder.quotationNumber,
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
            addressId: billingProvider.orderAddressId,
            pincode: billingProvider.orderPincode,
            deliveryCharge: deliveryCharge,
            customerType: customerTypeToSave,
            quotationId: currentOrder.quotationId,
            quotationNumber: currentOrder.quotationNumber,
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
          addressId: billingProvider.orderAddressId,
          pincode: billingProvider.orderPincode,
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
