import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:pos_machine/screens/sales/widgets/confirmed_order_detail_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

class ConfirmedOrdersScreen extends StatefulWidget {
  const ConfirmedOrdersScreen({super.key});

  @override
  State<ConfirmedOrdersScreen> createState() => _ConfirmedOrdersScreenState();
}

class _ConfirmedOrdersScreenState extends State<ConfirmedOrdersScreen> {
  List<SavedOrder> _attentionOrders(
    LocalProductProvider provider,
    LocalSaleSyncService saleSync,
  ) {
    return provider.confirmedOrders.where((order) {
      final record = saleSync.recordFor(order.id);
      return record?.state != LocalSaleSyncState.synced;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BuildBoxShadowContainer(
        circleRadius: 7,
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Consumer2<LocalProductProvider, LocalSaleSyncService>(
                builder: (context, provider, saleSync, child) {
                  // This screen is an action queue, not a sales history. Sales
                  // that have a verified server response belong in Sales; keep
                  // only records that still need an operator's attention here.
                  final attentionOrders = _attentionOrders(provider, saleSync);

                  if (attentionOrders.isEmpty) {
                    return const Center(
                      child: Text('No sales need sync attention.'),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 390,
                            mainAxisExtent: 238,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: attentionOrders.length,
                          itemBuilder: (context, index) {
                            final order = attentionOrders[index];
                            final syncRecord = saleSync.recordFor(order.id);
                            return _buildAttentionCard(
                              context: context,
                              order: order,
                              syncRecord: syncRecord,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionCard({
    required BuildContext context,
    required SavedOrder order,
    required LocalSaleSyncRecord? syncRecord,
  }) {
    final isRetryable = syncRecord?.state == LocalSaleSyncState.needsReview;
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';
    final guidance = switch (syncRecord?.state) {
      LocalSaleSyncState.needsReview =>
        'Check Sales first. Retry only when this order is not there.',
      LocalSaleSyncState.queued =>
        'Saved safely on this device. The first server attempt is waiting.',
      LocalSaleSyncState.sending =>
        'Saved safely on this device. Waiting for the server response.',
      LocalSaleSyncState.rejected =>
        'The server rejected this sale. Open details before taking action.',
      _ => 'This local sale needs your attention.',
    };

    return Semantics(
      button: true,
      label: 'Review sale ${order.orderNumber}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showOrderDetailsModal(context, order),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF4D8A8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${order.orderNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F3D75),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 19),
                        tooltip: 'Print receipt',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _printOrder(order),
                        color: ColorManager.kPrimaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildSyncBadge(syncRecord),
                  const SizedBox(height: 10),
                  Text(
                    guidance,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_formatDateTime(order.createdAt)} · ${_formatTime(order.createdAt)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '$currency${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: ColorManager.kPrimaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: isRetryable
                        ? FilledButton.icon(
                            onPressed: () => _confirmAndRetry(context, order),
                            icon: const Icon(Icons.replay, size: 17),
                            label: const Text('Review & retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB45309),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () =>
                                _showOrderDetailsModal(context, order),
                            icon:
                                const Icon(Icons.visibility_outlined, size: 17),
                            label: const Text('View details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String isoDateString) {
    return DateHelper.formatToISODateOnlyFromISO(isoDateString);
  }

  String _formatTime(String isoDateString) {
    return DateHelper.formatToISODateFromIST(isoDateString);
  }

  void _printOrder(SavedOrder order) async {
    try {
      await const PrintService().printSavedOrder(context, order);
      return;
    } catch (error) {
      debugPrint("Error printing order: ${error.toString()}");
      if (!mounted) return;
      showScaffoldError(
          context: context, message: "confirmed_orders.failed_print".tr);
    }
  }

  Future<void> _confirmAndRetry(BuildContext context, SavedOrder order) async {
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
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF9A5B07)),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'First check the backend Sales list. Retry only when this order is not there; otherwise a duplicate sale can be created.',
                      style: TextStyle(
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
            child: const Text('I verified — Retry'),
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

    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.trim().isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Please log in again before retrying this sale.',
      );
      return;
    }

    final saleSync = Provider.of<LocalSaleSyncService>(context, listen: false);
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
        message:
            'Retry started. This sale will update when the server responds.',
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

  void _showOrderDetailsModal(BuildContext context, SavedOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmedOrderDetailModal(order: order);
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, SavedOrder order) {
    DeleteConfirmationDialog.show(
      context: context,
      title: "confirmed_orders.delete_title".tr,
      itemName: order.orderNumber,
      message: "confirmed_orders.delete_message".tr,
      warningIcon: Icons.receipt_long_outlined,
      warningIconColor: ColorManager.kButtonRed,
      deleteButtonText: "confirmed_orders.delete".tr,
      onDelete: () async {
        // Delete the confirmed order from local storage
        final provider =
            Provider.of<LocalProductProvider>(context, listen: false);
        final saleSync =
            Provider.of<LocalSaleSyncService>(context, listen: false);
        await saleSync.remove(order.id);
        provider.deleteConfirmedOrder(order.id);
        await provider.flushPersistence();
        if (!context.mounted) return;

        // Show success message
        showScaffold(
          context: context,
          message: "confirmed_orders.delete_success".tr,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync attention',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s20,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Review saved sales that did not receive a verified server response.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Consumer2<LocalProductProvider, LocalSaleSyncService>(
            builder: (context, provider, sync, _) {
              final visibleCount = _attentionOrders(provider, sync).length;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: visibleCount == 0
                      ? const Color(0xFFEAF7EF)
                      : const Color(0xFFFFF3DE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: visibleCount == 0
                        ? const Color(0xFFB7E4C7)
                        : const Color(0xFFF5D49B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      visibleCount == 0
                          ? Icons.cloud_done_outlined
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: visibleCount == 0
                          ? const Color(0xFF16764A)
                          : const Color(0xFF9A5B07),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      visibleCount == 0
                          ? 'No sales need review'
                          : '$visibleCount sale${visibleCount == 1 ? '' : 's'} need review',
                      style: TextStyle(
                        color: visibleCount == 0
                            ? const Color(0xFF16764A)
                            : const Color(0xFF9A5B07),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBadge(LocalSaleSyncRecord? record) {
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
                    : '${_surfaceLabel(record.surface)} · $label',
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
