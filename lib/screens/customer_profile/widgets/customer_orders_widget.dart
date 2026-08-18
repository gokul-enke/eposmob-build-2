import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

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
  final SalesProvider _salesProvider = SalesProvider();
  List<ListOrderModelData> orders = [];
  bool isLoading = false;
  String? errorMessage;
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders(page: 1, showLoader: true);
    });
  }

  @override
  void didUpdateWidget(covariant CustomerOrdersWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id) {
      _loadOrders(page: 1, showLoader: true);
    }
  }

  Future<void> _loadOrders({required int page, bool showLoader = false}) async {
    final customerId = widget.customer.id;
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;

    if (customerId == null || accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        orders = [];
        errorMessage = customerId == null
            ? 'customer_orders.err_no_customer_id'.tr
            : 'customer_orders.err_login_again'.tr;
      });
      return;
    }

    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      await _salesProvider.fetchOrders(
        accessToken: accessToken,
        customerId: customerId,
        page: page,
      );

      if (!mounted) return;

      setState(() {
        orders = List<ListOrderModelData>.from(_salesProvider.orders);
        currentPage = _salesProvider.currentPage;
        totalPages = _salesProvider.totalPages;
        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        orders = [];
        errorMessage = 'customer_orders.err_load'.tr;
      });
    }
  }

  void _onPageChanged(int page) {
    if (page < 1 || page > totalPages || page == currentPage) {
      return;
    }
    _loadOrders(page: page, showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(widget.size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? _buildErrorState()
                      : orders.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                      padding: EdgeInsets.all(
                          widget.size.width < 600 ? 10 : 16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) =>
                          _buildOrderCard(orders[index]),
                    ),
            ),
            if (!isLoading && orders.isNotEmpty && totalPages > 1)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.size.width < 600 ? 10 : 16,
                  0,
                  widget.size.width < 600 ? 10 : 16,
                  widget.size.width < 600 ? 8 : 16,
                ),
                child: PaginationControl(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: _onPageChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = widget.size.width < 600;
    return Container(
      decoration: const BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 16,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag,
                        color: ColorManager.kPrimaryColor, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'customer_orders.title'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(FontWeightManager.bold,
                            FontSize.s16, 0, ColorManager.kTitleTextColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort, size: 20),
                      onPressed: () {},
                      color: ColorManager.kGreyColor,
                      tooltip: 'customer_orders.tooltip_sort'.tr,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    '(${orders.length}) · Page $currentPage/$totalPages',
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0, ColorManager.kGreyColor),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag,
                        color: ColorManager.kPrimaryColor, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      '${'customer_orders.title'.tr} (${orders.length})',
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s18, 0, ColorManager.kTitleTextColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () {},
                  color: ColorManager.kGreyColor,
                  tooltip: 'customer_orders.tooltip_sort'.tr,
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
            'customer_orders.title_empty'.tr,
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18, 0,
                ColorManager.kTitleTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'customer_orders.msg_empty'.tr,
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0,
                ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isMobile = widget.size.width < 600;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: isMobile ? 40 : 50, color: ColorManager.kRed),
            const SizedBox(height: 16),
            Text(
              'customer_orders.title_error'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.semiBold,
                  isMobile ? FontSize.s16 : FontSize.s18, 0,
                  ColorManager.kTitleTextColor),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 0),
              child: Text(
                errorMessage ?? 'customer_orders.err_unknown'.tr,
                textAlign: TextAlign.center,
                softWrap: true,
                style: buildCustomStyle(FontWeightManager.regular,
                    FontSize.s14, 0, ColorManager.kGreyColor),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadOrders(page: currentPage, showLoader: true),
              icon: const Icon(Icons.refresh),
              label: Text('customer_orders.btn_try_again'.tr),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(ListOrderModelData order) {
    final isMobile = widget.size.width < 600;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(color: ColorManager.kBgDarkColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: isMobile ? 4 : 8,
          ),
          leading: _buildOrderStatusIcon(order.status),
          title: Text(
            'Order #${order.orderNumber ?? 'N/A'}',
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(FontWeightManager.semiBold,
                isMobile ? FontSize.s13 : FontSize.s15, 0,
                ColorManager.kTitleTextColor),
          ),
          subtitle: Text(
            _formatDate(order.orderDate),
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0,
                ColorManager.kGreyColor),
          ),
          trailing: Consumer<AppSettingsProvider>(
            builder: (context, appSettingsProvider, child) {
              final currency =
                  appSettingsProvider.appSettings?.currency ?? 'INR';
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency${_getGrandTotal(order)}',
                    style: buildCustomStyle(FontWeightManager.bold,
                        isMobile ? FontSize.s12 : FontSize.s14, 0,
                        ColorManager.kSuccessColor),
                  ),
                  const SizedBox(height: 2),
                  _buildStatusBadge(order.status),
                ],
              );
            },
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

  Widget _buildOrderDetails(ListOrderModelData order) {
    final isMobile = widget.size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 8 : 12,
      ),
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
          _buildDetailRow('customer_orders.label_payment_status'.tr, order.paymentStatus,
              valueColor: _getPaymentStatusColor(order.paymentStatus)),
          _buildDetailRow('customer_orders.label_customer'.tr, _getCustomerDisplayName(order)),
          const Divider(height: 20),
          ..._buildOrderItemsList(order.cartItems),
          if (order.cartItems != null && order.cartItems!.isNotEmpty)
            const Divider(height: 20),
          if ((order.priceSummary?.taxTotal ?? '').isNotEmpty &&
              order.priceSummary?.taxTotal != '0.00')
            _buildTotalRow('customer_orders.label_tax'.tr, order.priceSummary?.taxTotal),
          const SizedBox(height: 8),
          _buildTotalRow('customer_orders.label_grand_total'.tr, _getGrandTotal(order), isGrandTotal: true),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItemsList(List<CartItem>? items) {
    if (items == null || items.isEmpty) {
      return [Text('customer_orders.msg_no_items'.tr)];
    }

    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';

    return items
        .map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${'customer_orders.label_product'.tr} ${item.productName ?? 'N/A'} (x${item.quantity ?? 0})',
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s12, 0, ColorManager.kTitleTextColor),
                    ),
                  ),
                  Text(
                    '$currency${item.totalPrice ?? '0.00'}',
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
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0,
                  ColorManager.kGreyColor)),
          Text(value ?? 'N/A',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                  0, valueColor ?? ColorManager.kTitleTextColor)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String? value,
      {bool isGrandTotal = false, Color? color}) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

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
                    : buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                        0, ColorManager.kGreyColor),
              ),
              Text(
                '$currency${value ?? '0.00'}',
                style: isGrandTotal
                    ? buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0,
                        color ?? ColorManager.kSuccessColor)
                    : buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                        0, color ?? ColorManager.kTitleTextColor),
              ),
            ],
          ),
        );
      },
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
    if (status == null) return ColorManager.grey; // Default color
    switch (status.toLowerCase()) {
      case 'paid':
        return ColorManager.kSuccessColor;
      case 'pending':
        return ColorManager.kRed;
      default:
        return ColorManager.grey; // Default fallback color
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getGrandTotal(ListOrderModelData order) {
    return order.priceSummary?.grandTotal ?? order.grantTotal ?? '0.00';
  }

  String _getCustomerDisplayName(ListOrderModelData order) {
    return order.customerName ??
        order.customerDetails?.name ??
        widget.customer.name ??
        'N/A';
  }

  String _formatPaymentMethod(dynamic paymentMethod) {
    if (paymentMethod == null) return 'N/A';
    if (paymentMethod is String) return paymentMethod;
    if (paymentMethod is List) return paymentMethod.join(', ');
    return 'customer_orders.label_multiple'.tr;
  }
}
