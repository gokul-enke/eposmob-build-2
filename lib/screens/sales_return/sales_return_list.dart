import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart' hide showScaffold, showScaffoldError, showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_detail_modal.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_responsive.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:provider/provider.dart';
import '../../components/build_pagination_control.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

class SalesReturnPage extends StatefulWidget {
  const SalesReturnPage({super.key});

  @override
  State<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends State<SalesReturnPage> {
  int currentPage = 1;
  final SideBarController sideBarController = Get.put(SideBarController());
  bool _isLoading = true;

  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchSalesReturns();
  }

  Future<void> _fetchSalesReturns() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      SalesProvider salesProvider =
          Provider.of<SalesProvider>(context, listen: false);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      await salesProvider.fetchSalesReturn(
          accessToken: accessToken ?? "", page: currentPage);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'sales_return.err_load'.tr;
        });
        showScaffoldError(
          context: context,
          message: _loadError!,
        );
      }
    }
  }

  void _searchSalesReturns(int page) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      SalesProvider salesProvider =
          Provider.of<SalesProvider>(context, listen: false);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      await salesProvider.fetchSalesReturn(
          accessToken: accessToken ?? "", page: page);

      if (mounted) {
        setState(() {
          currentPage = page;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'sales_return.err_load'.tr;
        });
        showScaffoldError(
          context: context,
          message: _loadError!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context, listen: true);

    return SalesReturnListShell(
      onRefresh: _fetchSalesReturns,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SalesReturnPageHeader(
            title: 'sales_return.title'.tr,
            subtitle: 'sales_return.subtitle'.tr,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SalesReturnContentCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  _isLoading && salesProvider.salesReturnOrders.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorManager.kPrimaryColor,
                          ),
                        )
                      : _buildSalesReturnContent(salesProvider),
                  if (_isLoading && salesProvider.salesReturnOrders.isNotEmpty)
                    Container(
                      color: Colors.white.withOpacity(0.6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildPaginationControls(salesProvider),
        ],
      ),
    );
  }

  Widget _buildSalesReturnContent(SalesProvider salesProvider) {
    if (_loadError != null && salesProvider.salesReturnOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        iconColor: Colors.red.shade300,
        title: _loadError!,
        titleColor: Colors.red.shade700,
        action: CustomRoundButton(
          title: 'restaurant.retry'.tr,
          fct: _fetchSalesReturns,
          fontSize: 12,
          height: 44,
          width: 140,
        ),
      );
    }

    if (salesProvider.salesReturnOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_return_outlined,
        iconColor: Colors.grey.shade400,
        title: 'sales_return.no_returns_found'.tr,
        titleColor: Colors.grey.shade600,
        subtitle: 'sales_return.start_return_hint'.tr,
        subtitleColor: Colors.grey.shade500,
      );
    }

    if (salesReturnIsPhone(context)) {
      return _buildMobileList(salesProvider);
    }

    return _buildDesktopTable(salesProvider);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    String? subtitle,
    Color? subtitleColor,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                titleColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.25,
                  subtitleColor ?? Colors.grey.shade500,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(SalesProvider salesProvider) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(12),
      itemCount: salesProvider.salesReturnOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = salesProvider.salesReturnOrders[index];
        return _buildMobileReturnCard(order);
      },
    );
  }

  Widget _buildMobileReturnCard(SalesReturnOrder order) {
    final totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );
    final bool isCompleted =
        order.status.toString() == '1' || order.status.toString() == 'true';
    final orderNumber =
        order.order?.orderNumber ?? order.orderId.toString();

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '#$orderNumber',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.20,
                              ColorManager.textColor,
                            ),
                          ),
                        ),
                        if (orderNumber.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: orderNumber));
                              showScaffold(
                                context: context,
                                message: 'sales_return.copy_success'.tr,
                              );
                            },
                            child: const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateHelper.formatISODate(order.createdAt.toString()),
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.15,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              SalesReturnStatusBadge(
                label: isCompleted ? 'sales_return.status_completed'.tr : 'sales_return.status_pending'.tr,
                isCompleted: isCompleted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMobileMetric(
                  'billing.table_qty'.tr,
                  totalQuantity.toString(),
                ),
              ),
              Expanded(
                child: Consumer<AppSettingsProvider>(
                  builder: (context, settings, _) {
                    final currency = settings.appSettings?.currency ?? 'INR';
                    final raw = order.totalAmount;
                    final parsed = double.tryParse(raw);
                    final amount =
                        parsed != null ? parsed.toStringAsFixed(2) : raw;
                    return _buildMobileMetric(
                      'sales_return.return_amount'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SalesReturnIconAction(
                icon: Icons.visibility,
                backgroundColor:
                    ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'billing.view_details'.tr,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SalesReturnDetailModal(order: order);
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              SalesReturnIconAction(
                icon: Icons.print,
                backgroundColor: Colors.green.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'sales_return.print_bill_tooltip'.tr,
                onPressed: () {
                  List<OrderReturnItem> returnItems = order.items.map((item) {
                    return OrderReturnItem(
                      id: item.id,
                      productName:
                          item.cartItem.product?.name ?? 'Unknown',
                      quantity: item.quantity.toInt(),
                      reason: item.reason,
                    );
                  }).toList();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReturnBillPrintPage(
                        returnItems: returnItems,
                        returnTotalAmount: order.totalAmount,
                        orderDate: order.createdAt.toString(),
                        orderNumber: order.order?.orderNumber ??
                            order.orderId.toString(),
                        customerName:
                            order.order?.customer?.user?.name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s10,
            0.15,
            Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(SalesProvider salesProvider) {
    return SalesReturnResponsiveTable(
      minWidth: 820,
      table: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorManager.tableBGColor.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
            ),
            child: Table(
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.5),
              },
              children: [_buildTableHeader()],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: salesProvider.salesReturnOrders.length,
              itemBuilder: (context, index) {
                SalesReturnOrder order =
                    salesProvider.salesReturnOrders[index];
                debugPrint('order.orderId ${order.orderId}');
                return Table(
                  border: TableBorder(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.12),
                    ),
                  ),
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.5),
                  },
                  children: [
                    _buildTableRow(order, index + 1),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      children: [
        'sales.order_number_hint'.tr,
        'sales_return.total_quantity'.tr,
        'sales_return.total_return_amount'.tr,
        'sales.status'.tr,
        'sales.date_col'.tr,
        'sales_return.action'.tr,
      ]
          .map((title) => TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(14),
                  child: Center(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  TableRow _buildTableRow(SalesReturnOrder order, int index) {
    int totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.withOpacity(0.04),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    order.order?.orderNumber ?? order.orderId.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.13,
                      Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: order.order?.orderNumber ??
                            order.orderId.toString()));
                    showScaffold(
                      context: context,
                      message: 'sales_return.copy_success'.tr,
                    );
                  },
                  child: const Icon(
                    Icons.copy,
                    size: 14,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildTableCell(totalQuantity.toString()),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Center(
              child: Consumer<AppSettingsProvider>(
                builder: (context, settings, _) {
                  final currency = settings.appSettings?.currency ?? 'INR';
                  final raw = order.totalAmount;
                  final parsed = double.tryParse(raw);
                  final amount =
                      parsed != null ? parsed.toStringAsFixed(2) : raw;
                  return Text(
                    '$currency $amount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.13,
                      Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        _buildStatusCell(order.status.toString()),
        _buildTableCell(DateHelper.formatISODate(order.createdAt.toString())),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SalesReturnIconAction(
                    icon: Icons.visibility,
                    backgroundColor:
                        ColorManager.kPrimaryColor.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'billing.view_details'.tr,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return SalesReturnDetailModal(order: order);
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  SalesReturnIconAction(
                    icon: Icons.print,
                    backgroundColor: Colors.green.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'sales_return.print_bill_tooltip'.tr,
                    onPressed: () {
                      List<OrderReturnItem> returnItems =
                          order.items.map((item) {
                        return OrderReturnItem(
                          id: item.id,
                          productName:
                              item.cartItem.product?.name ?? 'Unknown',
                          quantity: item.quantity.toInt(),
                          reason: item.reason,
                        );
                      }).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReturnBillPrintPage(
                            returnItems: returnItems,
                            returnTotalAmount: order.totalAmount,
                            orderDate: order.createdAt.toString(),
                            orderNumber: order.order?.orderNumber ??
                                order.orderId.toString(),
                            customerName:
                                order.order?.customer?.user?.name,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableCell _buildStatusCell(String text) {
    final bool isCompleted = text == '1' || text == 'true';
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Center(
          child: SalesReturnStatusBadge(
            label: isCompleted ? 'sales_return.status_completed'.tr : 'sales_return.status_pending'.tr,
            isCompleted: isCompleted,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls(SalesProvider salesProvider) {
    return PaginationControl(
      currentPage: salesProvider.salesReturnCurrentPage,
      totalPages: salesProvider.salesReturnTotalPages,
      onPageChanged: (int page) {
        _searchSalesReturns(page);
      },
    );
  }
}
