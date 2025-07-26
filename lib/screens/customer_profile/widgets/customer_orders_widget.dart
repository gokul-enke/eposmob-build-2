import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CustomerOrdersWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData customer;

  const CustomerOrdersWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  State<CustomerOrdersWidget> createState() => _CustomerOrdersWidgetState();
}

class _CustomerOrdersWidgetState extends State<CustomerOrdersWidget> {
  late List<CustomerOrder> orders;

  @override
  void initState() {
    super.initState();
    orders = widget.customer.orders ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: orders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(orders[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag,
                  color: ColorManager.kPrimaryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'Order History (${orders.length})',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                    ColorManager.kTitleTextColor),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {},
            color: ColorManager.kGreyColor,
            tooltip: 'Sort orders',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text(
            'No Orders Found',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                0, ColorManager.kTitleTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'This customer has not placed any orders yet.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s14, 0, ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(CustomerOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kBgDarkColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildOrderStatusIcon(order.status),
          title: Text(
            'Order #${order.orderNumber ?? 'N/A'}',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s15, 0,
                ColorManager.kTitleTextColor),
          ),
          subtitle: Text(
            _formatDate(order.orderDate),
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s12, 0, ColorManager.kGreyColor),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${order.grandTotal ?? '0.00'}',
                style: buildCustomStyle(
                    FontWeightManager.bold, FontSize.s14, 0, ColorManager.kSuccessColor),
              ),
              const SizedBox(height: 2),
              _buildStatusBadge(order.status),
            ],
          ),
          children: [_buildOrderDetails(order)],
        ),
      ),
    );
  }

  Widget _buildOrderStatusIcon(String? status) {
    IconData iconData;
    switch (status?.toLowerCase()) {
      case 'delivered':
        iconData = Icons.local_shipping;
        break;
      case 'completed':
        iconData = Icons.check_circle;
        break;
      case 'pending':
        iconData = Icons.pending_actions;
        break;
      case 'cancelled':
        iconData = Icons.cancel;
        break;
      default:
        iconData = Icons.help_outline;
    }
    return CircleAvatar(
      backgroundColor: _getStatusColor(status).withOpacity(0.1),
      child: Icon(iconData, color: _getStatusColor(status), size: 22),
    );
  }

  Widget _buildStatusBadge(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status?.toUpperCase() ?? 'N/A',
        style: buildCustomStyle(
            FontWeightManager.medium, FontSize.s10, 0, _getStatusColor(status)),
      ),
    );
  }

  Widget _buildOrderDetails(CustomerOrder order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: ColorManager.kBgLightColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Payment Status', order.paymentStatus,
              valueColor: _getPaymentStatusColor(order.paymentStatus)),
          _buildDetailRow(
              'Payment Method', _formatPaymentMethod(order.paymentMethod)),
          const Divider(height: 20),
          ..._buildOrderItemsList(order.items),
          const Divider(height: 20),
          _buildTotalRow('Subtotal', order.subTotal),
          if (order.discount != null && order.discount != '0.00')
            _buildTotalRow('Discount', '-${order.discount}',
                color: ColorManager.kRed),
          if (order.tax != null && order.tax != '0.00')
            _buildTotalRow('Tax', order.tax),
          const SizedBox(height: 8),
          _buildTotalRow('Grand Total', order.grandTotal, isGrandTotal: true),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItemsList(List<OrderItem>? items) {
    if (items == null || items.isEmpty) {
      return [const Text('No items in this order.')];
    }
    return items
        .map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Product ID: ${item.productId} (x${item.quantity})',
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s12, 0, ColorManager.kTitleTextColor),
                    ),
                  ),
                  Text(
                    '₹${item.totalPrice ?? '0.00'}',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0, ColorManager.kTitleTextColor),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Widget _buildDetailRow(String label, String? value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0, ColorManager.kGreyColor)),
          Text(value ?? 'N/A',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                  0, valueColor ?? ColorManager.kTitleTextColor)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String? value,
      {bool isGrandTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isGrandTotal
                ? buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0,
                    ColorManager.kTitleTextColor)
                : buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0,
                    ColorManager.kGreyColor),
          ),
          Text(
            '₹${value ?? '0.00'}',
            style: isGrandTotal
                ? buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0,
                    color ?? ColorManager.kSuccessColor)
                : buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                    0, color ?? ColorManager.kTitleTextColor),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return ColorManager.kSuccessColor;
      case 'pending':
        return ColorManager.kOrange;
      case 'cancelled':
        return ColorManager.kRed;
      default:
        return ColorManager.kGreyColor;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    return status?.toLowerCase() == 'paid'
        ? ColorManager.kSuccessColor
        : ColorManager.kRed;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatPaymentMethod(dynamic paymentMethod) {
    if (paymentMethod == null) return 'N/A';
    if (paymentMethod is String) return paymentMethod;
    if (paymentMethod is List) return paymentMethod.join(', ');
    return 'Multiple';
  }
}