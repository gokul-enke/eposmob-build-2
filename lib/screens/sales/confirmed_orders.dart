import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
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
                  final confirmedOrders = provider.confirmedOrders;

                  if (confirmedOrders.isEmpty) {
                    return Center(
                      child: Text('confirmed_orders.no_orders_found'.tr),
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
                            maxCrossAxisExtent: 360,
                            mainAxisExtent: 190,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: confirmedOrders.length,
                          itemBuilder: (context, index) {
                            final order = confirmedOrders[index];
                            final syncRecord = saleSync.recordFor(order.id);
                            String formattedDate =
                                _formatDateTime(order.createdAt);
                            String formattedTime = _formatTime(order.createdAt);

                            return GestureDetector(
                              onTap: () {
                                _showOrderDetailsModal(context, order);
                              },
                              child: BuildBoxShadowContainer(
                                circleRadius: 8,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${'sales.order_number_short'.tr}${order.orderNumber}',
                                              style: buildCustomStyle(
                                                FontWeightManager.bold,
                                                FontSize.s14,
                                                0.21,
                                                ColorManager.kPrimaryColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.print,
                                                    size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () =>
                                                    _printOrder(order),
                                                color:
                                                    ColorManager.kPrimaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: syncRecord != null &&
                                                        syncRecord.state !=
                                                            LocalSaleSyncState
                                                                .synced
                                                    ? null
                                                    : () =>
                                                        _showDeleteConfirmationDialog(
                                                            context, order),
                                                color: ColorManager.kButtonRed,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      _buildSyncBadge(syncRecord),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Text(
                                            formattedDate,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedTime,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Display Delivery Date (optional)
                                      if (order.deliveryDate != null &&
                                          order.deliveryDate!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${'confirmed_orders.delivery_date_prefix'.tr}${DateHelper.formatToISODateOnlyFromISO(order.deliveryDate!)}',
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s10,
                                            0.21,
                                            Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                      // Display Delivery Time (optional)
                                      if (order.deliveryTime != null &&
                                          order.deliveryTime!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${'confirmed_orders.delivery_time_prefix'.tr}${order.deliveryTime!}',
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s10,
                                            0.21,
                                            Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      // Show discount info if any discounts applied
                                      if ((order.flatDiscount != null &&
                                              order.flatDiscount! > 0) ||
                                          (order.percentageDiscount != null &&
                                              order.percentageDiscount! > 0) ||
                                          (order.couponId != null &&
                                              order.couponId!.isNotEmpty)) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.local_offer,
                                                size: 12, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              'confirmed_orders.discount_applied'
                                                  .tr,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s10,
                                                0.21,
                                                Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${'confirmed_orders.items_prefix'.tr}${order.items.length}',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              Colors.grey,
                                            ),
                                          ),
                                          Consumer<AppSettingsProvider>(
                                            builder: (context,
                                                appSettingsProvider, child) {
                                              final currency =
                                                  appSettingsProvider
                                                          .appSettings
                                                          ?.currency ??
                                                      'INR';
                                              return Text(
                                                '$currency${order.total.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: ColorManager
                                                      .kPrimaryColor,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              "confirmed_orders.title".tr,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Consumer<LocalSaleSyncService>(
            builder: (context, sync, _) => Flexible(
              child: Text(
                sync.unresolvedCount == 0
                    ? 'All recorded sales are synced'
                    : '${sync.unresolvedCount} sale(s) need sync attention',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: sync.unresolvedCount == 0
                      ? const Color(0xFF16764A)
                      : const Color(0xFF936014),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
