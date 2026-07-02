import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/orders_screen.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class MobileOrdersTab extends StatefulWidget {
  final Future<void> Function(String orderId) onOrderSelected;
  final Future<void> Function(SavedOrder order) onPrintOrder;
  final void Function(SavedOrder order) onDeleteOrder;
  final Future<void> Function() onNewOrder;
  final bool isLoadingOrder;
  final bool isCreatingNewOrder;

  const MobileOrdersTab({
    super.key,
    required this.onOrderSelected,
    required this.onPrintOrder,
    required this.onDeleteOrder,
    required this.onNewOrder,
    this.isLoadingOrder = false,
    this.isCreatingNewOrder = false,
  });

  @override
  State<MobileOrdersTab> createState() => _MobileOrdersTabState();
}

class _MobileOrdersTabState extends State<MobileOrdersTab> {
  @override
  Widget build(BuildContext context) {
    return OrdersScreen(
      onOrderSelected: widget.onOrderSelected,
      onPrintOrder: widget.onPrintOrder,
      onDeleteOrder: widget.onDeleteOrder,
      onNewOrder: widget.onNewOrder,
      isLoadingOrder: widget.isLoadingOrder,
      isCreatingNewOrder: widget.isCreatingNewOrder,
    );
  }
}
