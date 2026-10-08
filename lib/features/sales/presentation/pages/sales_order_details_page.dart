import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/order_details_view.dart';
import 'package:pos_machine/features/sales/presentation/widgets/details/order_returns_view.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';

import '../commands/detail/change_detail_order_status.dart';
import '../commands/detail/change_detail_payment_status.dart';
import '../commands/detail/print_detail_order.dart';
import '../commands/detail/return_detail_order.dart';
import '../commands/detail/share_detail_order.dart';
import '../sharing/sales_page_services.dart';
import '../state/sales_order_detail_controller.dart';
import '../widgets/details/order_detail_page_actions.dart';

class SalesOrderDetailsPage extends StatefulWidget {
  const SalesOrderDetailsPage({Key? key}) : super(key: key);

  @override
  State<SalesOrderDetailsPage> createState() => _SalesOrderDetailsPageState();
}

class _SalesOrderDetailsPageState extends State<SalesOrderDetailsPage> {
  final SideBarController sideBarController = Get.put(SideBarController());
  late final SalesPageServices _services;
  late final SalesOrderDetailController _controller;
  bool get isInitLoading => _controller.loading;
  String get orderNumber => _controller.orderNumber;
  String? get tokenNumber => _controller.tokenNumber;
  OrderDetailsModelData? get orderDetailsModelData => _controller.data;
  OrderDetailsModelDataCustomerDetails? get customerDetails =>
      _controller.customer;
  OrderDetailsModelDataCart? get cart => _controller.cart;
  List<OrderDetailsModelDataCartItem>? get cartItems => _controller.items;
  OrderDetailsModelDataPriceSummary? get priceSummary =>
      _controller.priceSummary;

  /// Credit-note config for the return section, resolved like the print flow
  /// (PrintPage.autoPrint); null when the order has no returns.

  @override
  void initState() {
    super.initState();
    _services = SalesPageServices.capture(context);
    _controller = SalesOrderDetailController(
        fetch: () => _services.sales.listOrderDetails(context,
            _services.sales.getOrderNumber, _services.auth.token ?? ''));
    _controller.addListener(_onChanged);
    getOrderDetails();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> getOrderDetails() => _controller.load();

  /// Helper method to check if a phone number matches the default customer phone from app settings

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final isMobile = ResponsiveWidget.isMobile(context);

    return SafeArea(
      child: MouseRegion(
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
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 4.0 : 10.0),
              padding: EdgeInsets.all(isMobile ? 4.0 : 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 22),
                boxShadow: const [
                  BoxShadow(
                    color: ColorManager.boxShadowColor,
                    blurRadius: 6,
                    offset: Offset(1, 1),
                  ),
                ],
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 12.0 : 20.0,
                  horizontal: isMobile ? 8.0 : 10.0,
                ),
                child: isInitLoading
                    ? SizedBox(
                        height: isMobile ? 240 : size.height,
                        child: const Center(
                            child: CircularProgressIndicator.adaptive()))
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // Align items to start
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 10),
                          SelectableText(
                            '${'sales_order_details.title'.tr} $orderNumber',
                            style: ResponsiveWidget.isMobile(context)
                                ? buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s12, 0.30, ColorManager.textColor)
                                : buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s20, 0.30, ColorManager.textColor),
                          ),
                          if (orderDetailsModelData?.receiptNumber
                                  ?.trim()
                                  .isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: SelectableText(
                                '${'sales.backend_order_number'.tr}: '
                                '${orderDetailsModelData?.orderNumber ?? '-'}',
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s11,
                                  0.16,
                                  Colors.black54,
                                ),
                              ),
                            ),
                          // Delivery Date/Time if present
                          if ((orderDetailsModelData?.orderProps != null) ||
                              orderDetailsModelData?.deliveryDate != null ||
                              orderDetailsModelData?.deliveryTime != null) ...[
                            Builder(
                              builder: (context) {
                                final dateProp = orderDetailsModelData
                                    ?.orderProps
                                    ?.firstWhere(
                                  (prop) =>
                                      prop.propsCode?.toUpperCase() ==
                                      'DELIVERY_DATE',
                                  orElse: () => OrderDetailsModelDataOrderProp(
                                      propsId: null,
                                      propsCode: null,
                                      propsValue: null),
                                );
                                final timeProp = orderDetailsModelData
                                    ?.orderProps
                                    ?.firstWhere(
                                  (prop) =>
                                      prop.propsCode?.toUpperCase() ==
                                      'DELIVERY_TIME',
                                  orElse: () => OrderDetailsModelDataOrderProp(
                                      propsId: null,
                                      propsCode: null,
                                      propsValue: null),
                                );
                                final effectiveDeliveryDate =
                                    dateProp?.propsValue?.isNotEmpty == true
                                        ? dateProp?.propsValue
                                        : orderDetailsModelData?.deliveryDate;
                                final effectiveDeliveryTime =
                                    timeProp?.propsValue?.isNotEmpty == true
                                        ? timeProp?.propsValue
                                        : orderDetailsModelData?.deliveryTime;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (effectiveDeliveryDate != null &&
                                        effectiveDeliveryDate.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '${'sales_order_details.label_delivery_date'.tr}\t${DateHelper.formatISODate(effectiveDeliveryDate)}',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              isMobile
                                                  ? FontSize.s12
                                                  : FontSize.s14,
                                              0.21,
                                              ColorManager.textColor),
                                        ),
                                      ),
                                    if (effectiveDeliveryTime != null &&
                                        effectiveDeliveryTime.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          '${'sales_order_details.label_delivery_time'.tr}\t$effectiveDeliveryTime',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              isMobile
                                                  ? FontSize.s12
                                                  : FontSize.s14,
                                              0.21,
                                              ColorManager.textColor),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          BuildBoxShadowContainer(
                            circleRadius: 12,
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            offsetValue: const Offset(1, 1),
                            child: OrderDetailPageActions(
                                onPrint: () => printDetailOrder(
                                    context, _controller, _services),
                                onShare: () => shareDetailOrder(
                                    context, _controller, _services),
                                onReturn: () => returnDetailOrder(
                                    context, _controller, _services),
                                onOrderStatus: () => changeDetailOrderStatus(
                                    context, _controller, _services),
                                onPaymentStatus: () =>
                                    changeDetailPaymentStatus(
                                        context, _controller, _services)),
                          ),
                          const SizedBox(height: 10),
                          _buildOrderDetails(),
                          const SizedBox(height: 10),
                          _buildOrderReturns(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            final isOnline = _services.sales.isOnlineSalesNavigation;
            SalesNavigation.openOrders(online: isOnline);
          },
          text: 'sales_order_details.btn_all_orders'.tr,
        ),
        BuildBoxShadowContainer(
          width: 15,
          height: 15,
          circleRadius: 10,
          color: ColorManager.kPrimaryColor,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              final isOnline = _services.sales.isOnlineSalesNavigation;
              SalesNavigation.openOrders(online: isOnline);
            },
            icon:
                const Icon(Icons.close_rounded, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails() {
    if (orderDetailsModelData == null) {
      return Text('sales_order_details.msg_no_order_data'.tr);
    }
    return OrderDetailWidget(
      orderDetailsModelData: orderDetailsModelData,
      priceSummary: priceSummary,
      cartItem: cartItems,
      customerDetails: customerDetails,
      onFulfillmentUpdated: getOrderDetails,
    );
  }

  Widget _buildOrderReturns() {
    // Check if orderReturns is null or has no return items
    if (orderDetailsModelData?.orderReturns == null ||
        (orderDetailsModelData?.orderReturns?.returnItems?.isEmpty ?? true)) {
      return const SizedBox(); // Return an empty SizedBox to hide the widget
    }

    // If there are return items, show the OrderReturnsWidget
    return OrderReturnsWidget(
      orderReturns: orderDetailsModelData?.orderReturns,
      cartItems: cartItems,
      priceSummary: priceSummary,
    );
  }
}
