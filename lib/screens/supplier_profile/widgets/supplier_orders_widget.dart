import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SupplierOrdersWidget extends StatefulWidget {
  final Size size;
  final Supplier supplier;

  const SupplierOrdersWidget({
    Key? key,
    required this.size,
    required this.supplier,
  }) : super(key: key);

  @override
  State<SupplierOrdersWidget> createState() => _SupplierOrdersWidgetState();
}

class _SupplierOrdersWidgetState extends State<SupplierOrdersWidget> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildEmptyState(),
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
                'Orders',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                    ColorManager.kTitleTextColor),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_alt),
                onPressed: () {},
                color: ColorManager.kGreyColor,
                tooltip: 'Filter orders',
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {},
                color: ColorManager.kGreyColor,
                tooltip: 'Search orders',
              ),
            ],
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
          Text('No Orders Found',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                  0, ColorManager.kTitleTextColor)),
          const SizedBox(height: 8),
          Text(
            'Order data is not available for this supplier.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0,
                ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }
}

// Simple model for supplier orders (this would need to be defined properly based on your API)
class SupplierOrder {
  final String orderNumber;
  final String date;
  final String status;
  final int itemsCount;
  final String totalAmount;
  final String paymentMethod;
  final String supplierName;

  SupplierOrder({
    required this.orderNumber,
    required this.date,
    required this.status,
    required this.itemsCount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.supplierName,
  });
}
