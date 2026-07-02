import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders/order_status_badge.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onEdit,
  });

  final SavedOrder order;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  bool get _isReady {
    final status = order.status?.trim().toLowerCase() ?? '';
    return status.contains('ready') ||
        status.contains('complete') ||
        status.contains('pickup');
  }

  String get _statusLabel => _isReady ? 'Ready' : 'Preparing';

  Color get _statusColor => _isReady ? Colors.green : Colors.orange;

  String get _orderNumber {
    final number =
        order.orderNumber.trim().isNotEmpty ? order.orderNumber : order.id;
    return number.startsWith('#') ? number : '#$number';
  }

  String get _supportingText {
    final note = order.comment?.trim();
    final delivery = order.deliveryMethod?.trim();
    final suffix = note?.isNotEmpty == true
        ? note!
        : delivery?.isNotEmpty == true
            ? delivery!
            : 'Special Instructions';
    return '${order.items.length} items - $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OrderStatusBadge(
                    label: _statusLabel,
                    color: _statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                order.customerName?.trim().isNotEmpty == true
                    ? order.customerName!.trim()
                    : 'Walk-in Customer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.blueGrey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    _isReady ? Icons.restaurant_menu : Icons.coffee_outlined,
                    size: 18,
                    color: Colors.blueGrey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _supportingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '\$${order.total.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: ColorManager.kPrimaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  _isReady
                      ? _CompleteButton(onTap: onTap)
                      : _EditButton(onTap: onEdit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          height: 32,
          width: 106,
          child: Center(
            child: Text(
              'Complete',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorManager.kPrimaryColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          height: 32,
          width: 36,
          child: Icon(
            Icons.edit,
            color: ColorManager.kPrimaryColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}
