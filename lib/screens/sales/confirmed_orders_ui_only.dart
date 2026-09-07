import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

// Dummy Data Models
class DummyProduct {
  final String productId;
  final String productName;
  final double mrp;
  final double price;

  DummyProduct({
    required this.productId,
    required this.productName,
    required this.mrp,
    required this.price,
  });
}

class DummyOrderItem {
  final DummyProduct product;
  final int quantity;
  final double price;
  final double mrp;

  DummyOrderItem({
    required this.product,
    required this.quantity,
    required this.price,
    required this.mrp,
  });
}

class DummyOrder {
  final String id;
  final String orderNumber;
  final String createdAt;
  final List<DummyOrderItem> items;
  final double total;
  final String? deliveryDate;
  final String? deliveryTime;
  final String? customerPhone;
  final String paymentMethod;
  final String status;

  DummyOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.items,
    required this.total,
    this.deliveryDate,
    this.deliveryTime,
    this.customerPhone,
    required this.paymentMethod,
    required this.status,
  });
}

// Color Manager
class ColorManager {
  static const Color kPrimaryColor = Color(0xFF2196F3);
  static const Color kButtonRed = Color(0xFFE53935);
  static const Color textColor = Color(0xFF333333);
  static const Color cardBackground = Color(0xFFF8F9FA);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
}

// Font Manager
class FontWeightManager {
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

class FontSize {
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s18 = 18.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
}

// Style Builder
TextStyle buildCustomStyle(
    FontWeight weight, double size, double letterSpacing, Color color) {
  return TextStyle(
    fontWeight: weight,
    fontSize: size,
    letterSpacing: letterSpacing,
    color: color,
  );
}

// Container Widget
class BuildBoxShadowContainer extends StatelessWidget {
  final Widget child;
  final double circleRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const BuildBoxShadowContainer({
    Key? key,
    required this.child,
    this.circleRadius = 8,
    this.margin,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(circleRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Custom Button Widget
class CustomRoundButton extends StatelessWidget {
  final String title;
  final VoidCallback fct;
  final double fontSize;
  final double height;
  final double width;

  const CustomRoundButton({
    Key? key,
    required this.title,
    required this.fct,
    this.fontSize = 14,
    this.height = 50,
    this.width = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ColorManager.successGreen, Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: ColorManager.successGreen.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: fct,
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConfirmedOrdersScreen extends StatefulWidget {
  const ConfirmedOrdersScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmedOrdersScreen> createState() => _ConfirmedOrdersScreenState();
}

class _ConfirmedOrdersScreenState extends State<ConfirmedOrdersScreen>
    with TickerProviderStateMixin {
  bool isSyncing = false;
  int currentSyncIndex = 0;
  int totalOrdersToSync = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Beautiful Dummy Data
  late List<DummyOrder> confirmedOrders;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _initializeDummyData();
  }

  void _initializeDummyData() {
    confirmedOrders = [
      DummyOrder(
        id: "1",
        orderNumber: "ORD-2024-001",
        createdAt:
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        total: 1250.75,
        paymentMethod: "UPI",
        status: "confirmed",
        customerPhone: "+91 98765 43210",
        deliveryDate:
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        deliveryTime: "2:00 PM - 4:00 PM",
        items: [
          DummyOrderItem(
            product: DummyProduct(
              productId: "1",
              productName: "Premium Coffee Blend",
              mrp: 499.0,
              price: 449.0,
            ),
            quantity: 2,
            price: 449.0,
            mrp: 499.0,
          ),
          DummyOrderItem(
            product: DummyProduct(
              productId: "2",
              productName: "Artisan Dark Chocolate",
              mrp: 299.0,
              price: 259.0,
            ),
            quantity: 1,
            price: 259.0,
            mrp: 299.0,
          ),
        ],
      ),
      DummyOrder(
        id: "2",
        orderNumber: "ORD-2024-002",
        createdAt:
            DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        total: 899.50,
        paymentMethod: "CARD",
        status: "confirmed",
        customerPhone: "+91 87654 32109",
        items: [
          DummyOrderItem(
            product: DummyProduct(
              productId: "4",
              productName: "Wireless Bluetooth Earbuds",
              mrp: 999.0,
              price: 849.0,
            ),
            quantity: 1,
            price: 849.0,
            mrp: 999.0,
          ),
          DummyOrderItem(
            product: DummyProduct(
              productId: "5",
              productName: "Phone Protection Case",
              mrp: 79.0,
              price: 59.0,
            ),
            quantity: 1,
            price: 59.0,
            mrp: 79.0,
          ),
        ],
      ),
      DummyOrder(
        id: "3",
        orderNumber: "ORD-2024-003",
        createdAt:
            DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        total: 2150.00,
        paymentMethod: "CASH",
        status: "confirmed",
        customerPhone: "+91 76543 21098",
        deliveryDate:
            DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        deliveryTime: "10:00 AM - 12:00 PM",
        items: [
          DummyOrderItem(
            product: DummyProduct(
              productId: "6",
              productName: "Smart Fitness Watch",
              mrp: 2499.0,
              price: 2199.0,
            ),
            quantity: 1,
            price: 2199.0,
            mrp: 2499.0,
          ),
        ],
      ),
      DummyOrder(
        id: "4",
        orderNumber: "ORD-2024-004",
        createdAt:
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        total: 750.25,
        paymentMethod: "UPI",
        status: "confirmed",
        customerPhone: "+91 65432 10987",
        items: [
          DummyOrderItem(
            product: DummyProduct(
              productId: "7",
              productName: "Gourmet Pizza Margherita",
              mrp: 449.0,
              price: 399.0,
            ),
            quantity: 1,
            price: 399.0,
            mrp: 449.0,
          ),
          DummyOrderItem(
            product: DummyProduct(
              productId: "8",
              productName: "Fresh Caesar Salad",
              mrp: 299.0,
              price: 249.0,
            ),
            quantity: 1,
            price: 249.0,
            mrp: 299.0,
          ),
        ],
      ),
      DummyOrder(
        id: "5",
        orderNumber: "ORD-2024-005",
        createdAt: DateTime.now()
            .subtract(const Duration(days: 1, hours: 5))
            .toIso8601String(),
        total: 1599.99,
        paymentMethod: "CARD",
        status: "confirmed",
        customerPhone: "+91 54321 09876",
        items: [
          DummyOrderItem(
            product: DummyProduct(
              productId: "10",
              productName: "Premium Skincare Set",
              mrp: 1799.0,
              price: 1599.0,
            ),
            quantity: 1,
            price: 1599.0,
            mrp: 1799.0,
          ),
        ],
      ),
      DummyOrder(
        id: "6",
        orderNumber: "ORD-2024-006",
        createdAt:
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        total: 3250.00,
        paymentMethod: "UPI",
        status: "confirmed",
        customerPhone: "+91 43210 98765",
        deliveryDate:
            DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        deliveryTime: "6:00 PM - 8:00 PM",
        items: [
          DummyOrderItem(
            product: DummyProduct(
              productId: "11",
              productName: "Gaming Mechanical Keyboard",
              mrp: 3499.0,
              price: 3199.0,
            ),
            quantity: 1,
            price: 3199.0,
            mrp: 3499.0,
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 50 * (1 - _fadeAnimation.value)),
              child: BuildBoxShadowContainer(
                circleRadius: 12,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildStatsCards(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildOrdersGrid()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCards() {
    final totalRevenue =
        confirmedOrders.fold<double>(0, (sum, order) => sum + order.total);
    final totalOrders = confirmedOrders.length;
    final avgOrderValue = totalRevenue / totalOrders;

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        return Row(
          children: [
            Expanded(
                child: _buildStatCard("Total Orders", totalOrders.toString(),
                    Icons.receipt_long, ColorManager.kPrimaryColor)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    "Revenue",
                    "$currency${totalRevenue.toStringAsFixed(0)}",
                    Icons.trending_up,
                    ColorManager.successGreen)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    "Avg. Order",
                    "$currency${avgOrderValue.toStringAsFixed(0)}",
                    Icons.analytics,
                    ColorManager.warningOrange)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return BuildBoxShadowContainer(
      circleRadius: 12,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_upward, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: buildCustomStyle(FontWeightManager.bold, FontSize.s24, 0.0,
                  ColorManager.textColor),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                  0.0, Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersGrid() {
    if (confirmedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'confirmed_orders.no_orders_found'.tr,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s18,
                  0.0, Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.4, // Made more compact
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: confirmedOrders.length,
          itemBuilder: (context, index) {
            final order = confirmedOrders[index];
            return _buildOrderCard(order, index);
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(DummyOrder order, int index) {
    String formattedDate = _formatDateTime(order.createdAt);
    String formattedTime = _formatTime(order.createdAt);

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 600 + (index * 100)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: GestureDetector(
                onTap: () => _showOrderDetailsModal(context, order),
                child: BuildBoxShadowContainer(
                  circleRadius: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Section: Order Number & Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ColorManager.kPrimaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  order.orderNumber,
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s12,
                                    0.0,
                                    ColorManager.kPrimaryColor,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildActionButton(
                                      Icons.print,
                                      ColorManager.kPrimaryColor,
                                      () => _printOrder(order)),
                                  const SizedBox(width: 6),
                                  _buildActionButton(
                                      Icons.delete_outline,
                                      ColorManager.kButtonRed,
                                      () => _showDeleteConfirmationDialog(
                                          context, order)),
                                ],
                              ),
                            ],
                          ),

                          // Middle Section: Time & Delivery Info
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$formattedDate • $formattedTime',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.0,
                                      Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              if (order.deliveryDate != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.local_shipping,
                                        size: 12,
                                        color: ColorManager.successGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                      'confirmed_orders.delivery_date_prefix'.tr +
                                          _formatDateTime(order.deliveryDate!),
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s10,
                                        0.0,
                                        ColorManager.successGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),

                          // Bottom Section: Items, Payment & Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'confirmed_orders.items_prefix'.tr +
                                        order.items.length.toString(),
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.0,
                                      Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getPaymentMethodColor(
                                              order.paymentMethod)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      order.paymentMethod,
                                      style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s10,
                                        0.0,
                                        _getPaymentMethodColor(
                                            order.paymentMethod),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$currency${order.total.toStringAsFixed(2)}',
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  FontSize.s16,
                                  0.0,
                                  ColorManager.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 14),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        color: color,
      ),
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'UPI':
        return ColorManager.successGreen;
      case 'CARD':
        return ColorManager.kPrimaryColor;
      case 'CASH':
        return ColorManager.warningOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String isoDateString) {
    return DateHelper.formatISODate(isoDateString);
  }

  String _formatTime(String isoDateString) {
    return DateHelper.formatISODateToIST(isoDateString);
  }

  void _printOrder(DummyOrder order) {
    // Show print confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('confirmed_orders.msg_printing_order'.trParams({'number': order.orderNumber})),
        backgroundColor: ColorManager.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showOrderDetailsModal(BuildContext context, DummyOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<AppSettingsProvider>(
          builder: (context, appSettingsProvider, child) {
            final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.orderNumber,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s24,
                            0.0,
                            ColorManager.textColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    ...order.items
                        .map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ColorManager.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.productName,
                                          style: buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            FontSize.s14,
                                            0.0,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                        Text(
                                          'confirmed_orders.quantity_prefix'.tr +
                                              item.quantity.toString(),
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.0,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$currency${(item.price * item.quantity).toStringAsFixed(2)}',
                                    style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s14,
                                      0.0,
                                      ColorManager.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'confirmed_orders.total_amount'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s18,
                            0.0,
                            ColorManager.textColor,
                          ),
                        ),
                        Text(
                          '$currency${order.total.toStringAsFixed(2)}',
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s20,
                            0.0,
                            ColorManager.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, DummyOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: ColorManager.kButtonRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'confirmed_orders.delete_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s20,
                    0.0,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'confirmed_orders.delete_message'.trParams(
                    {'number': order.orderNumber},
                  ),
                  textAlign: TextAlign.center,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.0,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('general.cancel'.tr),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            confirmedOrders
                                .removeWhere((o) => o.id == order.id);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('confirmed_orders.msg_order_deleted'.trParams({'number': order.orderNumber})),
                              backgroundColor: ColorManager.kButtonRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.kButtonRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('confirmed_orders.delete'.tr),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'confirmed_orders.title'.tr,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s24,
                0.0,
                ColorManager.textColor,
              ),
            ),
            Text(
              'confirmed_orders.subtitle'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.0,
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
        CustomRoundButton(
          title: 'confirmed_orders.sync_btn'.tr,
          fct: () => _syncConfirmedOrders(),
          fontSize: 14,
          height: 48,
          width: 200,
        ),
      ],
    );
  }

  void _syncConfirmedOrders() {
    if (confirmedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('confirmed_orders.no_orders_to_sync'.tr),
          backgroundColor: ColorManager.kButtonRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Show beautiful sync dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width / 3,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ColorManager.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.sync,
                    size: 48,
                    color: ColorManager.successGreen,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'confirmed_orders.syncing_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s24,
                    0.0,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'confirmed_orders.uploading_orders'.trParams(
                    {'count': confirmedOrders.length.toString()},
                  ),
                  textAlign: TextAlign.center,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.0,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(ColorManager.successGreen),
                ),
                const SizedBox(height: 16),
                Text(
                  'confirmed_orders.sync_wait'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.0,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Simulate sync process
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'confirmed_orders.successfully_synced'.trParams(
              {'count': confirmedOrders.length.toString()},
            ),
          ),
          backgroundColor: ColorManager.successGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }
}
