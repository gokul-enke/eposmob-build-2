import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_sales_services.dart';

Future<void> confirmAndRetryLocalSale(
    BuildContext context, SavedOrder order, LocalSalesServices services) async {
  final record = services.sync.recordFor(order.id);
  final isRejected = record?.state == LocalSaleSyncState.rejected;
  final warning = isRejected
      ? 'The server rejected this sale${record?.message?.isNotEmpty == true ? ': ${record!.message}' : '.'}\n\n'
          'The same data will be sent again, so fix the cause on the server '
          'first (for example stock or customer details). Check the log to '
          'see the exact request and response.'
      : 'First check the backend Sales list. Retry only when this order is '
          'not there; otherwise a duplicate sale can be created.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 560),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          SizedBox(width: 10),
          Text('Retry this saved sale?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${order.orderNumber} will be sent to the server one more time.',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF5D49B)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFF9A5B07)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      color: Color(0xFF7C4A03),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(isRejected ? 'Retry' : 'I verified — Retry'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB45309),
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 44),
          ),
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
    await saleSync.authorizeRetryAfterVerification(order.id);
    unawaited(
      saleSync.submitOnce(
        localOrderId: order.id,
        accessToken: accessToken,
      ),
    );
    if (!context.mounted) return;
    showScaffold(
      context: context,
      message: 'Retry started. This sale will update when the server responds.',
    );
  } on StateError catch (error) {
    if (!context.mounted) return;
    showScaffoldError(context: context, message: error.message.toString());
  } catch (_) {
    if (!context.mounted) return;
    showScaffoldError(
      context: context,
      message: 'Could not start the retry. The sale remains saved locally.',
    );
  }
}
