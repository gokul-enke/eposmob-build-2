import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/navigation/sales_navigation.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales/presentation/widgets/orders/mobile_order_card.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:provider/provider.dart';

import '../commands/mobile/print_mobile_order.dart';
import '../commands/mobile/show_mobile_order_options.dart';
import '../commands/pick_sales_date_time.dart';
import '../commands/sales_order_cancel.dart';
import '../commands/sales_order_payment.dart';
import '../commands/sales_order_return_items.dart';
import '../commands/sales_order_share.dart';
import '../commands/sales_order_status.dart';
import '../sharing/sales_page_services.dart';
import '../sharing/sales_pdf_sharing.dart';
import '../sharing/sales_whatsapp_sharing.dart';
import '../state/sales_list_controller.dart';
import '../widgets/orders/sales_action_icon.dart';
import '../widgets/orders/sales_desktop_filters.dart';
import '../widgets/orders/sales_empty_state.dart';
import '../widgets/orders/sales_error_state.dart';
import '../widgets/orders/sales_filter_toggle.dart';
import '../widgets/orders/sales_mobile_filters.dart';
import '../widgets/orders/sales_more_options_sheet.dart';
import '../widgets/orders/sales_orders_table.dart';
import '../widgets/orders/sales_pagination.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key, this.isOnlineSales = false});
  final bool isOnlineSales;
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final SalesListController controller;
  late final SalesPageServices services;
  late final PurchaseProvider purchase;
  @override
  void initState() {
    super.initState();
    services = SalesPageServices.capture(context);
    purchase = context.read<PurchaseProvider>();
    controller = SalesListController(
        isOnlineSales: widget.isOnlineSales,
        activeStore: () => services.store.activeStore?.storeId?.toString(),
        onError: (message) {
          if (mounted) showScaffoldError(context: context, message: message);
        },
        fetch: (query) => services.sales.fetchOrders(
            accessToken: services.auth.token ?? '',
            storeId: query.storeId,
            orderNumber: query.orderNumber,
            filterName: query.filterName,
            date: query.date,
            from: query.from,
            until: query.until,
            businessDate: query.businessDate,
            customerId: query.customerId,
            productId: query.productId,
            filterStatus: query.filterStatus,
            filterPrice: query.filterPrice,
            filterEmail: query.filterEmail,
            filterPhone: query.filterPhone,
            filterStore: query.filterStore,
            filterCreatedBy: query.filterCreatedBy,
            page: query.page,
            filterOnlineSales: query.filterOnlineSales));
    services.sales.isOnlineSalesNavigation = widget.isOnlineSales;
    controller.addListener(_changed);
    controller.loadInitData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) services.sales.setFiltersVisibility(!_isMobile(context));
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SalesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnlineSales != widget.isOnlineSales) {
      controller.isOnlineSales = widget.isOnlineSales;
      services.sales.isOnlineSalesNavigation = widget.isOnlineSales;
      resetSearch();
    }
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  void resetSearch() {
    controller.resetSearch();
    if (_isMobile(context)) services.sales.setFiltersVisibility(false);
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  Future<void> _sharePDFInvoice(ListOrderModelData order) =>
      shareSalesPdf(context, services, order);
  Future<void> _shareViaWhatsAppBot(ListOrderModelData order) =>
      shareSalesWhatsapp(context, services, order);

  Future<void> _selectDateTime(BuildContext context,
      {required bool isFromDate}) async {
    final value = await pickSalesDateTime(context, isFromDate: isFromDate);
    if (!mounted || value == null) return;
    controller.update(() {
      if (isFromDate) {
        controller.fromDateController.text = value;
      } else {
        controller.toDateController.text = value;
      }
    });
    controller.searchOrders(1);
  }

  Widget _buildActionButtons(ListOrderModelData order, BuildContext context) =>
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SalesActionIcon(
                icon: Icons.visibility,
                color: ColorManager.kPrimaryColor,
                onPressed: () {
                  services.sales.setOrderNumber(order.orderNumber ?? '0');
                  services.sales.isOnlineSalesNavigation = widget.isOnlineSales;
                  SalesNavigation.openDetails();
                }),
            SalesActionIcon(
                icon: Icons.print,
                color: Colors.blue,
                onPressed: () async {
                  try {
                    final number = order.orderNumber;
                    if (number == null || number.isEmpty) return;
                    await const PrintService()
                        .printOrderByIdWithOptions(context, number);
                  } catch (error) {
                    debugPrint(error.toString());
                  }
                }),
            SalesActionIcon(
                icon: Icons.more_vert,
                color: Colors.blue,
                onPressed: () async {
                  if (!context.mounted) return;
                  await showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (ctx) => SalesMoreOptionsSheet(
                          order: order,
                          onShare: (sheet) => shareSalesOrder(context, sheet,
                              services, order, widget.isOnlineSales),
                          onReturnItems: (sheet) => returnItemsSalesOrder(
                              context,
                              sheet,
                              services,
                              order,
                              widget.isOnlineSales),
                          onCancel: (sheet) => cancelSalesOrder(context, sheet,
                              services, order, widget.isOnlineSales),
                          onStatus: (sheet) =>
                              statusSalesOrder(context, sheet, services, order, widget.isOnlineSales),
                          onPayment: (sheet) => paymentSalesOrder(context, sheet, services, order, widget.isOnlineSales)));
                })
          ]);
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider = purchase;
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: _isMobile(context) ? 8 : 12,
            vertical: _isMobile(context) ? 10 : 20,
          ),
          padding: EdgeInsets.all(_isMobile(context) ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_isMobile(context) ? 16 : 20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: _isMobile(context) ? 12.0 : 20.0,
              horizontal: _isMobile(context) ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.isOnlineSales
                            ? 'sales.online_orders_list'.tr
                            : 'sales.orders_list'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s20,
                          0.30,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Consumer<SalesProvider>(
                      builder: (context, salesProvider, child) {
                        return SalesFilterToggle(
                            controller: controller,
                            showFilters: salesProvider.showFilters,
                            onToggle: salesProvider.toggleFilters);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Search and Filter Section - Responsive (conditionally shown)
                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    if (!salesProvider.showFilters) {
                      return const SizedBox.shrink();
                    }

                    return ConstrainedBox(
                      key: const ValueKey('orders-list-filters'),
                      constraints: BoxConstraints(
                        maxHeight: size.height * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: _isMobile(context)
                            ? SalesMobileFilters(
                                controller: controller,
                                size: size,
                                storeList: storeList ?? [],
                                onReset: resetSearch,
                                onPickDate: (from) =>
                                    _selectDateTime(context, isFromDate: from))
                            : SalesDesktopFilters(
                                controller: controller,
                                onReset: resetSearch,
                                onPickDate: (from) =>
                                    _selectDateTime(context, isFromDate: from)),
                      ),
                    );
                  },
                ),

                Consumer<SalesProvider>(
                  builder: (context, salesProvider, child) {
                    return salesProvider.showFilters
                        ? const SizedBox(height: 20)
                        : const SizedBox.shrink();
                  },
                ),
                Expanded(
                  child: Consumer<SalesProvider>(
                    builder: (context, orderProvider, child) {
                      if (controller.initLoading) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: ColorManager.kPrimaryColor,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'sales.loading_orders'.tr,
                                style: const TextStyle(
                                  color: ColorManager.kGreyColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final displayedOrders = orderProvider.orders;

                      // A failed request is not the same as "no orders": show
                      // the failure (with a retry) instead of claiming the
                      // store has no matching orders. A later successful fetch
                      // clears the provider error and the list comes back.
                      if (controller.lastRequestFailed &&
                          orderProvider.ordersError != null) {
                        return SalesErrorState(
                            onRetry: () => controller.searchOrders(1),
                            message: orderProvider.ordersError!);
                      }

                      if (displayedOrders.isEmpty) {
                        // Pass displayedOrders to empty state for correct message
                        return SalesEmptyState(
                            isOnlineSales: widget.isOnlineSales,
                            hasActiveFilters: controller.hasActiveFilters,
                            hasUnmatchedOrders: displayedOrders.isEmpty &&
                                orderProvider.orders.isNotEmpty,
                            onReset: resetSearch);
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: _isMobile(context)
                                ? ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: displayedOrders.length,
                                    itemBuilder: (context, index) {
                                      final order = displayedOrders[index];
                                      return MobileOrderCard(
                                        currency: services.settings.appSettings
                                                ?.currency ??
                                            'INR',
                                        onView: () {
                                          services.sales.setOrderNumber(
                                              order.orderNumber ?? '0');
                                          SalesNavigation.openDetails();
                                        },
                                        onPrint: () => printMobileOrder(
                                            context,
                                            order,
                                            services,
                                            _sharePDFInvoice,
                                            _shareViaWhatsAppBot),
                                        onOptions: () => showMobileOrderOptions(
                                            context,
                                            order,
                                            services,
                                            _sharePDFInvoice,
                                            _shareViaWhatsAppBot),
                                        order: displayedOrders[index],
                                        index: index,
                                        onSharePDF: _sharePDFInvoice,
                                        onShareWhatsApp: _shareViaWhatsAppBot,
                                      );
                                    },
                                  )
                                : SalesOrdersTable(
                                    displayedOrders: displayedOrders,
                                    paginationFrom:
                                        orderProvider.paginationFrom,
                                    currency: services
                                            .settings.appSettings?.currency ??
                                        'INR',
                                    actionsBuilder: (context, order) =>
                                        _buildActionButtons(order, context)),
                          ),
                          SalesPagination(
                            currentPage: orderProvider.currentPage,
                            totalPages: orderProvider.totalPages,
                            onPageChanged: (int page) {
                              controller.searchOrders(page);
                            },
                          ),
                        ],
                      );
                    },
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
