import 'package:flutter/material.dart';
import 'package:pos_machine/features/offers/domain/offer_money.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

import 'local_sales_services.dart';

/// Reconstructs the same API body for legacy retry, bulk sync and JSON editing.
Map<String, dynamic> buildLegacySaleRequest(
  BuildContext context,
  SavedOrder order,
  LocalSalesServices services,
) {
  final pay = PaymentHelper.buildApiPaymentPayloadFromLocal(
    context: context,
    storedPaymentMethod: order.paymentMethod,
    storedPaidAmount: order.paidAmount,
    storedBalanceAmount: order.balanceAmount,
  );
  final subtotal = order.items.fold<double>(
    0,
    (sum, item) =>
        sum +
        (item.price != null
            ? item.amounts.total
            : roundMoney((item.product.price?.price ?? 0) * item.quantity)),
  );
  final discount = (order.flatDiscount ?? 0) +
      roundMoney(subtotal * (order.percentageDiscount ?? 0) / 100);
  return OrderSubmissionPayload(
    items: LocalProductProvider.buildOrderItemsPayloadFrom(order.items),
    transactionNumber: order.transactionId ?? '',
    customerId: order.customerId,
    customerPhone: order.customerPhone ?? '',
    paymentMethod: pay.paymentMethod,
    paidAmount: pay.paidAmount,
    paymentMethods: pay.paymentMethods,
    paidMethods: pay.paidMethods,
    balanceAmount: order.balanceAmount ?? '0.0',
    couponId: order.couponId,
    comment: order.comment,
    deliveryMethodId: order.deliveryMethodId,
    carNumber: order.carNumber,
    status: 'confirmed',
    deliveryDate: order.deliveryDate,
    deliveryTime: order.deliveryTime,
    tableId: order.tableId,
    flatDiscount: order.flatDiscount,
    percentageDiscount: order.percentageDiscount,
    discountAmount: discount > subtotal ? subtotal : discount,
    toCustomerCredit: order.toCustomerCredit,
    address: order.address,
    addressId: order.addressId,
    pincode: order.pincode,
    quotationId: order.quotationId,
    deliveryCharge: order.deliveryCharge ?? 0,
    storeId: services.store.activeStore?.storeId,
  ).toApiJson();
}
