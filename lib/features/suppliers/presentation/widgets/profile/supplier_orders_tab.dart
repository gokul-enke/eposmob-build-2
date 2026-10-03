import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/supplier.dart';
import '../../state/supplier_orders_controller.dart';
import 'orders/supplier_orders_view.dart';

/// Supplier profile "All Orders" tab: the supplier's purchase orders (the
/// ones that came with the supplier record), 20 per page. Needs the
/// purchase-orders permission.
class SupplierOrdersTab extends StatefulWidget {
  const SupplierOrdersTab({super.key, required this.supplier});

  final Supplier supplier;

  @override
  State<SupplierOrdersTab> createState() => _SupplierOrdersTabState();
}

class _SupplierOrdersTabState extends State<SupplierOrdersTab> {
  late final SupplierOrdersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SupplierOrdersController(
      fetch: () async => widget.supplier.purchases,
    )..load();
  }

  @override
  void didUpdateWidget(covariant SupplierOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.supplier, widget.supplier)) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!canViewPurchasePrice(context)) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'supplier_profile.orders_permission'.tr,
      );
    }
    final currency = context.select<AppSettingsProvider, String>(
      (settings) => settings.appSettings?.currency ?? 'INR',
    );
    return SupplierOrdersView(controller: _controller, currency: currency);
  }
}
