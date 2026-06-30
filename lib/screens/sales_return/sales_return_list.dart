import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_detail_modal.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:provider/provider.dart';
import '../../components/build_container_box.dart';
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
              : 'Failed to load sales returns';
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
              : 'Failed to load sales returns';
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchSalesReturns,
        child: Container(
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Expanded(
                  child: BuildBoxShadowContainer(
                    circleRadius: 7,
                    offsetValue: const Offset(1, 1),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : _buildSalesReturnTable(salesProvider),
                  ),
                ),
                const SizedBox(height: 20),
                _buildPaginationControls(salesProvider),
              ],
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
        Text(
          "Sales Return Orders",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.end,
        //   children: [
        //     CustomRoundButton(
        //       title: "Create Sales Return",
        //       fct: () {
        //         sideBarController.index.value = 49;
        //       },
        //       fontSize: 12,
        //       height: 45,
        //       width: 200,
        //     ),
        //   ],
        // ),
      ],
    );
  }

  Widget _buildSalesReturnTable(SalesProvider salesProvider) {
    if (_loadError != null && salesProvider.salesReturnOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            CustomRoundButton(
              title: 'Retry',
              fct: _fetchSalesReturns,
              fontSize: 12,
              height: 40,
              width: 120,
            ),
          ],
        ),
      );
    }

    if (salesProvider.salesReturnOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No sales returns yet',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a return from Sales → order actions → Return',
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.25,
                Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Table(
          border: const TableBorder.symmetric(
            outside:
                BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
            inside:
                BorderSide(color: ColorManager.tableBOrderColor, width: 0.8),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.5), // Order Number
            1: FlexColumnWidth(1), // Quantity
            2: FlexColumnWidth(2), // Amount
            3: FlexColumnWidth(1), // Status
            4: FlexColumnWidth(1.5), // Date
            5: FlexColumnWidth(1.5), // Action
          },
          children: [
            _buildTableHeader(),
          ],
        ),

        // ListView for table rows
        Expanded(
          child: ListView.builder(
            itemCount: salesProvider.salesReturnOrders.length,
            itemBuilder: (context, index) {
              SalesReturnOrder order = salesProvider.salesReturnOrders[index];
              debugPrint('order.orderId ${order.orderId}');
              return Table(
                border: const TableBorder.symmetric(
                  outside: BorderSide(
                      color: ColorManager.tableBOrderColor, width: 0.3),
                  inside: BorderSide(
                      color: ColorManager.tableBOrderColor, width: 0.8),
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FlexColumnWidth(1.5), // Order Number
                  1: FlexColumnWidth(1), // Quantity
                  2: FlexColumnWidth(2), // Amount
                  3: FlexColumnWidth(1), // Status
                  4: FlexColumnWidth(1.5), // Date
                  5: FlexColumnWidth(1.5), // Action
                },
                children: [
                  _buildTableRow(order, index + 1),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration:
          BoxDecoration(color: ColorManager.tableBGColor.withOpacity(0.4)),
      children: [
        "Order Number",
        "Total Quantity",
        "Total Return Amount",
        "Status",
        "Date",
        "Action"
      ]
          .map((title) => TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Center(
                    child: Text(
                      title,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
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
    // Calculate total quantity by summing all item quantities
    int totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );

    return TableRow(
      children: [
        _buildTableCell(order.order?.orderNumber ?? order.orderId.toString()),
        _buildTableCell(totalQuantity.toString()),
        // Total Return Amount with currency
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Center(
              child: Consumer<AppSettingsProvider>(
                builder: (context, settings, _) {
                  final currency = settings.appSettings?.currency ?? 'INR';
                  final raw = order.totalAmount; // string
                  final parsed = double.tryParse(raw);
                  final amount =
                      parsed != null ? parsed.toStringAsFixed(2) : raw;
                  return Text(
                    '$currency $amount',
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
        _buildTableCell(order.status.toString(), isStatusCell: true),
        _buildTableCell(DateHelper.formatISODate(order.createdAt.toString())),
        TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // View button
                    BuildBoxShadowContainer(
                        margin: const EdgeInsets.only(left: 5, right: 5),
                        color: ColorManager.kPrimaryColor.withOpacity(0.9),
                        circleRadius: 5,
                        child: IconButton(
                          icon: const Icon(
                            Icons.visibility,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            // Show modal with sales return details
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return SalesReturnDetailModal(order: order);
                              },
                            );
                          },
                        )),
                    // Print button
                    BuildBoxShadowContainer(
                        margin: const EdgeInsets.only(left: 5, right: 5),
                        color: Colors.green.withOpacity(0.9),
                        circleRadius: 5,
                        child: IconButton(
                          icon: const Icon(
                            Icons.print,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            // Convert SalesReturnOrder items to OrderReturnItem list
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

                            // Navigate to Return Bill Print Page
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
                        )),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isStatusCell = false}) {
    if (isStatusCell) {
      final bool isCompleted = text == '1' || text == 'true';
      final String statusLabel = isCompleted ? 'Completed' : 'Pending';
      final Color statusColor = isCompleted ? Colors.green : Colors.orange;

      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.schedule,
                    color: statusColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.13,
                      statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Default text cell
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
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
