import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'build_legacy_sale_request.dart';
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

  try {
    final payload = buildLegacySaleRequest(context, order, services);
    await saleSync.enqueue(
      localOrderId: order.id,
      localOrderNumber: order.orderNumber,
      sourceCartSessionId: order.id,
      surface: LocalSaleSurface.legacy,
      payload: payload,
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
