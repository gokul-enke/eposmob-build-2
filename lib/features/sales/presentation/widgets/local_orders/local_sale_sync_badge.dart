import 'package:flutter/material.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

class LocalSaleSyncBadge extends StatelessWidget {
  const LocalSaleSyncBadge({super.key, required this.record});
  final LocalSaleSyncRecord? record;
  @override
  Widget build(BuildContext context) {
    final state = record?.state;
    final (label, color, icon) = switch (state) {
      LocalSaleSyncState.queued => (
          'Waiting to send',
          const Color(0xFF6B7280),
          Icons.schedule_outlined
        ),
      LocalSaleSyncState.sending => (
          'Sending',
          const Color(0xFF2563EB),
          Icons.sync
        ),
      LocalSaleSyncState.synced => (
          record?.serverOrderNumber?.isNotEmpty == true
              ? 'Synced · ${record!.serverOrderNumber}'
              : 'Synced',
          const Color(0xFF16764A),
          Icons.cloud_done_outlined,
        ),
      LocalSaleSyncState.needsReview => (
          'Needs review',
          const Color(0xFFB45309),
          Icons.warning_amber_rounded,
        ),
      LocalSaleSyncState.rejected => (
          'Rejected',
          const Color(0xFFB42318),
          Icons.error_outline,
        ),
      null => ('Local only', const Color(0xFF6B7280), Icons.cloud_off_outlined),
    };
    return Tooltip(
      message: record?.message ?? 'This legacy local order has no sync record.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                record == null
                    ? label
                    : '${_surfaceLabel(record!.surface)} · $label',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _surfaceLabel(LocalSaleSurface surface) => switch (surface) {
        LocalSaleSurface.supermarketDesktop => 'Desktop',
        LocalSaleSurface.mobileBilling => 'Mobile',
        LocalSaleSurface.restaurant => 'Restaurant',
        LocalSaleSurface.attender => 'Attender',
        LocalSaleSurface.kiosk => 'Kiosk',
        LocalSaleSurface.legacy => 'Legacy',
      };
}
