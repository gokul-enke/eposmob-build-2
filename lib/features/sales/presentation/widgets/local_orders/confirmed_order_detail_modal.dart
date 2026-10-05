import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

import 'detail/local_order_detail_delete.dart';
import 'detail/local_order_detail_inputs.dart';
import 'detail/local_order_detail_print.dart';
import 'detail/local_order_detail_view.dart';

class ConfirmedOrderDetailModal extends StatefulWidget {
  const ConfirmedOrderDetailModal({super.key, required this.order});
  final SavedOrder order;
  @override
  State<ConfirmedOrderDetailModal> createState() =>
      _ConfirmedOrderDetailModalState();
}

class _ConfirmedOrderDetailModalState extends State<ConfirmedOrderDetailModal> {
  late final AppSettingsProvider settings;
  late final LocalSaleSyncService sync;
  late final LocalProductProvider products;
  BillingProvider? billing;
  @override
  void initState() {
    super.initState();
    settings = context.read<AppSettingsProvider>();
    sync = context.read<LocalSaleSyncService>();
    products = context.read<LocalProductProvider>();
    try {
      billing = context.read<BillingProvider>();
    } on ProviderNotFoundException {
      billing = null;
    }
  }

  String methodLabel(String value) {
    if (RegExp(r'^\d+$').hasMatch(value)) {
      final b = billing;
      if (b != null) {
        if (value == b.cashPaymentMethodId) return 'CASH';
        if (value == b.cardPaymentMethodId) return 'CARD';
        if (value == b.upiPaymentMethodId) return 'UPI';
        if (value == b.codPaymentMethodId) return 'COD';
      }
      return 'confirmed_orders.payment_hash'.tr.replaceAll('@id', value);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([settings, sync]),
      builder: (context, child) => LocalOrderDetailView(
          inputs: LocalOrderDetailInputs(
              order: widget.order,
              currency: settings.appSettings?.currency ?? 'INR',
              record: sync.recordFor(widget.order.id),
              methodLabel: methodLabel,
              onPrint: () => printConfirmedSaleDetail(context, widget.order),
              onDelete: () => deleteConfirmedSaleDetail(
                  context, widget.order, products, sync),
              onClose: () => Navigator.of(context).pop())));
}
