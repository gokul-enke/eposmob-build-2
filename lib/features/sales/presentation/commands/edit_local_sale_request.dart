import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import '../widgets/local_orders/local_sale_request_editor.dart';
import 'build_legacy_sale_request.dart';
import 'local_sales_services.dart';

Future<void> editLocalSaleRequest(
    BuildContext context, SavedOrder order, LocalSalesServices services) async {
  try {
    final record = services.sync.recordFor(order.id);
    if (record != null &&
        (!record.canEditRequest || services.sync.isSubmitting(order.id))) {
      throw StateError(
          'This sale cannot be edited while sending or after it is resolved.');
    }
    final payload =
        record?.payload ?? buildLegacySaleRequest(context, order, services);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocalSaleRequestEditor(
        orderNumber: order.orderNumber,
        payload: payload,
        onSave: (edited) async {
          if (services.sync.recordFor(order.id) == null) {
            await services.sync.enqueue(
                localOrderId: order.id,
                localOrderNumber: order.orderNumber,
                sourceCartSessionId: order.id,
                surface: LocalSaleSurface.legacy,
                payload: edited);
          } else {
            await services.sync.updateRequestPayload(order.id, edited);
          }
        },
      ),
    );
    if (saved == true && context.mounted) {
      showScaffold(
          context: context,
          message: 'Request saved. Sync this order when you are ready.');
    }
  } catch (error) {
    if (context.mounted) {
      showScaffoldError(
          context: context,
          message: error is StateError
              ? error.message.toString()
              : 'Could not open the request editor.');
    }
  }
}
