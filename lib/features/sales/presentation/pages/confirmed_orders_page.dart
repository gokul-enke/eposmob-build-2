import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

import '../commands/confirm_and_delete_local_sale.dart';
import '../commands/confirm_and_dismiss_local_sale.dart';
import '../commands/confirm_and_retry_legacy_sale.dart';
import '../commands/confirm_and_retry_local_sale.dart';
import '../commands/local_sales_services.dart';
import '../commands/print_local_sale.dart';
import '../commands/show_local_sale_details.dart';
import '../commands/show_local_sale_sync_log.dart';
import '../widgets/local_orders/local_sale_attention_card.dart';
import '../widgets/local_orders/local_sales_header.dart';

class ConfirmedOrdersPage extends StatefulWidget {
  const ConfirmedOrdersPage({super.key});

  @override
  State<ConfirmedOrdersPage> createState() => _ConfirmedOrdersPageState();
}

class _ConfirmedOrdersPageState extends State<ConfirmedOrdersPage> {
  late final LocalSalesServices _services;
  @override
  void initState() {
    super.initState();
    _services = LocalSalesServices.capture(context);
  }

  List<SavedOrder> _attentionOrders(
    LocalProductProvider provider,
    LocalSaleSyncService saleSync,
  ) {
    return provider.confirmedOrders.where((order) {
      final record = saleSync.recordFor(order.id);
      return record?.state != LocalSaleSyncState.synced &&
          record?.isDismissed != true;
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
            Consumer2<LocalProductProvider, LocalSaleSyncService>(
                builder: (context, provider, sync, _) => LocalSalesHeader(
                    visibleCount: _attentionOrders(provider, sync).length)),
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
                            return LocalSaleAttentionCard(
                              currency:
                                  _services.settings.appSettings?.currency ??
                                      "INR",
                              onView: () => showLocalSaleDetails(
                                  context, order, _services),
                              onRetryLegacy: () => confirmAndRetryLegacySale(
                                  context, order, _services),
                              onRetry: () => confirmAndRetryLocalSale(
                                  context, order, _services),
                              onDismiss: () => confirmAndDismissLocalSale(
                                  context, order, _services),
                              onDelete: () => confirmAndDeleteLocalSale(
                                  context, order, _services),
                              onLog: () => showLocalSaleSyncLog(
                                  context, order.id, _services),
                              onPrint: () =>
                                  printLocalSale(context, order, _services),
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

  /// Old local-only orders (saved by builds before the outbox) have no stored
  /// request. Rebuild one from the saved order, put it in the outbox so it has
  /// a log and Remove like every other sale, and send it once.
}
