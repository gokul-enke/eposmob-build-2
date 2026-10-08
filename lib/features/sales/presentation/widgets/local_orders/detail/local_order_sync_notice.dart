import 'package:flutter/material.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_order_detail_inputs.dart';

class LocalOrderSyncNotice extends StatelessWidget {
  const LocalOrderSyncNotice(this.record, {super.key, required this.inputs});
  final LocalOrderDetailInputs inputs;
  final LocalSaleSyncRecord record;
  @override
  Widget build(BuildContext context) {
    final isRejected = record.state == LocalSaleSyncState.rejected;
    final color =
        isRejected ? const Color(0xFFB42318) : const Color(0xFFB45309);
    final title =
        isRejected ? 'Server rejected this sale' : 'Server result needs review';
    final message = isRejected
        ? (record.message ??
            'Open the sale details and correct the problem before creating a new sale.')
        : 'Check the backend Sales list before retrying. Retry only if this order is not present.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRejected ? const Color(0xFFFFF1F2) : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.error_outline : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
