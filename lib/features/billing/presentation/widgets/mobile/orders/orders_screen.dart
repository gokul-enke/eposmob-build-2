import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/order_card.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/orders_empty_state.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({
    super.key,
    required this.onOrderSelected,
    required this.onPrintOrder,
    required this.onDeleteOrder,
    required this.onNewOrder,
    this.isLoadingOrder = false,
    this.isCreatingNewOrder = false,
  });

  final Future<void> Function(String orderId) onOrderSelected;
  final Future<void> Function(SavedOrder order) onPrintOrder;
  final void Function(SavedOrder order) onDeleteOrder;
  final Future<void> Function() onNewOrder;
  final bool isLoadingOrder;
  final bool isCreatingNewOrder;

  bool get _isBusy => isLoadingOrder || isCreatingNewOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Consumer<LocalProductProvider>(
            builder: (context, provider, _) {
              final orders = provider.savedOrders;
              final selectedOrderId = provider.currentOrder?.id;

              return Column(
                children: [
                  _NewOrderButton(
                    onPressed: _isBusy ? null : () => onNewOrder(),
                    isCreatingNewOrder: isCreatingNewOrder,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: orders.isEmpty
                        ? const OrdersEmptyState()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return OrderCard(
                                order: order,
                                isSelected: selectedOrderId == order.id,
                                onTap: _isBusy
                                    ? null
                                    : () => onOrderSelected(order.id),
                                onPrint: _isBusy
                                    ? null
                                    : () => onPrintOrder(order),
                                onDelete: _isBusy
                                    ? null
                                    : () => onDeleteOrder(order),
                                isLoadingOrder: isLoadingOrder,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({
    required this.onPressed,
    required this.isCreatingNewOrder,
  });

  final VoidCallback? onPressed;
  final bool isCreatingNewOrder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCreatingNewOrder)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.add_circle,
                    size: 24,
                    color: ColorManager.kPrimaryColor,
                  ),
                const SizedBox(width: 12),
                Text(
                  'common.create_new_order'.tr,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
