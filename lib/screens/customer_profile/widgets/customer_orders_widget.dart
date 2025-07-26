import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:provider/provider.dart';

class CustomerOrdersWidget extends StatelessWidget {
  final Size size;
  final CustomerListModelData customer;
  final String accessToken; // Added accessToken parameter

  const CustomerOrdersWidget({
    Key? key,
    required this.size,
    required this.customer,
    required this.accessToken, // Required access token
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orders = customer.orders ?? [];
    final bool isSmallScreen = size.width < 1200;
    final double contentWidth = isSmallScreen ? size.width / 1.8 : size.width / 2;

    return Expanded(
      child: BuildBoxShadowContainer(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      height: size.height * 0.75,
      width: contentWidth,
      circleRadius: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(context),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            _buildEmptyState()
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshOrders(context),
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _buildOrderCard(orders[index]),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Order History (${customer.orders?.length ?? 0})',
          style: const TextStyle(
            fontSize: FontSize.s20,
            fontWeight: FontWeightManager.semiBold
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _refreshOrders(context),
          tooltip: 'Refresh orders',
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No orders found for this customer',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(CustomerOrder order) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      circleRadius: 7,
      child: ExpansionTile(
        title: Row(
          children: [
            _buildOrderStatusIndicator(order.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderNumber ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatDate(order.orderDate),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '₹${order.grandTotal ?? '0.00'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderDetailRow('Payment Status:', order.paymentStatus),
                _buildOrderDetailRow('Payment Method:', _formatPaymentMethod(order.paymentMethod)),
                _buildOrderDetailRow('Subtotal:', '₹${order.subTotal ?? '0.00'}'),
                if (order.discount != null && order.discount != '0.00')
                  _buildOrderDetailRow('Discount:', '-₹${order.discount}'),
                if (order.tax != null && order.tax != '0.00')
                  _buildOrderDetailRow('Tax:', '₹${order.tax}'),
                const Divider(),
                const Text(
                  'Order Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._buildOrderItemsList(order.items),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusIndicator(String? status) {
    Color color;
    IconData icon;
    
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'delivered':

        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'processing':
        color = Colors.blue;
        icon = Icons.autorenew;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Tooltip(
      message: status ?? 'Unknown status',
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildOrderDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItemsList(List<OrderItem>? items) {
    if (items == null || items.isEmpty) {
      return [const Text('No items found')];
    }

    return items.map((item) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Product ID: ${item.productId}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            '${item.quantity}x',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 16),
          Text(
            '₹${item.totalPrice ?? '0.00'}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    )).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatPaymentMethod(dynamic paymentMethod) {
    if (paymentMethod == null) return 'N/A';
    if (paymentMethod is String) return paymentMethod;
    if (paymentMethod is List) return paymentMethod.join(', ');
    return paymentMethod.toString();
  }

Future<void> _refreshOrders(BuildContext context) async {
  final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
  
  try {
    await customerProvider.fetchUserById(
      accessToken,
      customer.id!,
      context,
    );
    // Success: Just pop if you're in a dialog, or do nothing if it's a background refresh
    Navigator.pop(context); // Only if you're inside a dialog/modal
  } catch (e) {
    // Check if the error is an authentication issue
    if (e.toString().contains("401") || e.toString().contains("Unauthorized")) {
      // Option 1: Show an error and let the user manually log in again
      showScaffoldError(
        context: context,
        message: "Session expired. Please log in again.",
      );
      // Option 2: Automatically navigate to login (if that's your app's flow)
      // Navigator.pushReplacementNamed(context, '/login');
    } else {
      // Other errors (network issues, etc.)
      showScaffoldError(
        context: context,
        message: 'Error refreshing orders: ${e.toString()}',
      );
    }
  }
}
}