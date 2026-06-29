import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/orders_screen.dart';

class MobileOrdersTab extends StatefulWidget {
  final void Function(String orderId) onOrderSelected;

  const MobileOrdersTab({
    super.key,
    required this.onOrderSelected,
  });

  @override
  State<MobileOrdersTab> createState() => _MobileOrdersTabState();
}

class _MobileOrdersTabState extends State<MobileOrdersTab> {
  @override
  Widget build(BuildContext context) {
    return OrdersScreen(onOrderSelected: widget.onOrderSelected);
  }
}
