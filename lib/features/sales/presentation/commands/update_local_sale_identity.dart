import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'build_legacy_sale_request.dart';
import 'local_sales_services.dart';

/// The receipt number the next sync will send: the request's
/// `receipt_number`, or the local order number when the request has none.
String localSaleReceiptNumber(SavedOrder order, LocalSaleSyncRecord? record) {
  final value = record?.payload['receipt_number']?.toString().trim();
  return value == null || value.isEmpty ? order.orderNumber : value;
}

/// The sale time the next sync will send: the request's `issued_at`, or the
/// local order time when the request has none.
String localSaleIssuedAt(SavedOrder order, LocalSaleSyncRecord? record) {
  final value = record?.payload['issued_at']?.toString().trim();
  return value == null || value.isEmpty ? order.createdAt : value;
}

/// Saves a corrected receipt number and/or sale time into the next request
/// for [order]. Like the JSON editor, it never changes past attempts or the
/// saved receipt, and nothing is sent until the operator syncs.
Future<bool> updateLocalSaleIdentity(
  BuildContext context,
  SavedOrder order,
  LocalSalesServices services, {
  String? receiptNumber,
  String? issuedAt,
}) async {
  try {
    final record = services.sync.recordFor(order.id);
    if (record != null &&
        (!record.canEditRequest || services.sync.isSubmitting(order.id))) {
      throw StateError(
          'This sale cannot be edited while sending or after it is resolved.');
    }
    final payload = Map<String, dynamic>.from(
        record?.payload ?? buildLegacySaleRequest(context, order, services));
    if (receiptNumber != null) payload['receipt_number'] = receiptNumber;
    if (issuedAt != null) payload['issued_at'] = issuedAt;
    if (record == null) {
      await services.sync.enqueue(
          localOrderId: order.id,
          localOrderNumber: order.orderNumber,
          sourceCartSessionId: order.id,
          surface: LocalSaleSurface.legacy,
          payload: payload);
    } else {
      await services.sync.updateRequestPayload(order.id, payload);
    }
    if (context.mounted) {
      showScaffold(
          context: context,
          message: receiptNumber != null
              ? 'Receipt number updated. Sync the order to send it.'
              : 'Sale date and time updated. Sync the order to send it.');
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showScaffoldError(
          context: context,
          message: error is StateError
              ? error.message.toString()
              : 'Could not save the change. Try again.');
    }
    return false;
  }
}
