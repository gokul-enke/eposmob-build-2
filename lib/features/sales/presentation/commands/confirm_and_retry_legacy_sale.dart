import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/offers/domain/offer_money.dart';
import 'package:pos_machine/helpers/payment_helper.dart';
import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sales_services.dart';

Future<void> confirmAndRetryLegacySale(
  BuildContext context,
  SavedOrder order,
  LocalSalesServices services,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 560),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          SizedBox(width: 10),
          Text('Send this old local sale?'),
        ],
      ),
      content: Text(
        'Order #${order.orderNumber} was saved on this device by an older '
        'version and has never been sent. It has no duplicate protection, so '
        'first check the backend Sales list. Send it only when this order is '
        'not there.',
        style: const TextStyle(color: Color(0xFF7C4A03), height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB45309),
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 44),
          ),
          child: const Text('I verified — Send'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final accessToken = services.auth.token;
  if (accessToken == null || accessToken.trim().isEmpty) {
    showScaffoldError(
      context: context,
      message: 'Please log in again before retrying this sale.',
    );
    return;
  }

  final saleSync = services.sync;
  final storeId = services.store.activeStore?.storeId;
  try {
    final pay = PaymentHelper.buildApiPaymentPayloadFromLocal(
      context: context,
      storedPaymentMethod: order.paymentMethod,
      storedPaidAmount: order.paidAmount,
      storedBalanceAmount: order.balanceAmount,
    );
    final payload = OrderSubmissionPayload(
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
      discountAmount: _legacyDiscountAmount(order),
      toCustomerCredit: order.toCustomerCredit,
      address: order.address,
      addressId: order.addressId,
      pincode: order.pincode,
      quotationId: order.quotationId,
      deliveryCharge: order.deliveryCharge ?? 0,
      storeId: storeId,
    );
    await saleSync.enqueue(
      localOrderId: order.id,
      localOrderNumber: order.orderNumber,
      sourceCartSessionId: order.id,
      surface: LocalSaleSurface.legacy,
      payload: payload.toApiJson(),
    );
    unawaited(
      saleSync.submitOnce(localOrderId: order.id, accessToken: accessToken),
    );
    if (!context.mounted) return;
    showScaffold(
      context: context,
      message:
          'Sending started. This sale will update when the server responds.',
    );
  } catch (_) {
    if (!context.mounted) return;
    showScaffoldError(
      context: context,
      message: 'Could not start the send. The sale remains saved locally.',
    );
  }
}

double _legacyDiscountAmount(SavedOrder order) {
  // Same rounded line totals and percentage discount as the cart charged.
  final subtotal = order.items.fold<double>(
    0.0,
    (sum, item) =>
        sum +
        (item.price != null
            ? item.amounts.total
            : roundMoney((item.product.price?.price ?? 0.0) * item.quantity)),
  );
  final total = (order.flatDiscount ?? 0.0) +
      roundMoney(subtotal * (order.percentageDiscount ?? 0.0) / 100);
  return total > subtotal ? subtotal : total;
}
