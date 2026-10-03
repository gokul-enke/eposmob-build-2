import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// ZATCA bulk-sync bar above the invoice table: Sync ALL / Failed / Not
/// sent / Selected on the left, the selection count with Select page and
/// Unselect on the right (stacked below 1000 px).
class InvoiceZatcaToolbar extends StatelessWidget {
  const InvoiceZatcaToolbar({
    super.key,
    required this.disabled,
    required this.isBulkSending,
    required this.activeSyncType,
    required this.selectedCount,
    required this.onSync,
    required this.onSelectPage,
    required this.onUnselect,
  });

  /// Sync and Select page are unavailable (sending, loading, Phase 2 not
  /// verified, no token).
  final bool disabled;
  final bool isBulkSending;

  /// Mode whose sync is running ('all', 'failed', 'not_sent', 'selected').
  final String? activeSyncType;
  final int selectedCount;
  final ValueChanged<String> onSync;
  final VoidCallback onSelectPage;
  final VoidCallback onUnselect;

  static const wideBreakpoint = 1000.0;

  Widget _sync(String mode, String label, Color color) => FilledButton(
      onPressed: disabled || (mode == 'selected' && selectedCount == 0)
          ? null
          : () => onSync(mode),
      style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control))),
      child: Text(isBulkSending && activeSyncType == mode
          ? 'invoice.sending'.tr
          : label));

  @override
  Widget build(BuildContext context) {
    final syncActions = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _sync('all', 'invoice.sync_all_button'.tr, Colors.blueAccent),
        _sync('failed', 'invoice.sync_failed_button'.tr, Colors.redAccent),
        _sync('not_sent', 'invoice.sync_not_send_button'.tr, Colors.orange),
        _sync('selected', 'invoice.sync_selected_button'.tr, Colors.blueAccent),
      ],
    );
    final selectionActions = Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('invoice.records_selected'.trParams({'count': '$selectedCount'})),
        TextButton(
            onPressed: disabled ? null : onSelectPage,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text('invoice.select_page'.tr)),
        TextButton(
            onPressed: isBulkSending ? null : onUnselect,
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text('invoice.unselect'.tr)),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= wideBreakpoint) {
        return Row(
          children: [
            Expanded(flex: 3, child: syncActions),
            const SizedBox(width: 16),
            Flexible(
              flex: 2,
              child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: selectionActions),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          syncActions,
          const SizedBox(height: AppSpacing.sm),
          Align(
              alignment: AlignmentDirectional.centerEnd,
              child: selectionActions),
        ],
      );
    });
  }
}
