import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_detail_modal.dart';
import 'package:provider/provider.dart';
import '../../components/build_container_box.dart';
import '../../components/build_pagination_control.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SalesReturnPage extends StatefulWidget {
  const SalesReturnPage({super.key});

  @override
  State<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends State<SalesReturnPage> {
  int currentPage = 1;
  final SideBarController sideBarController = Get.put(SideBarController());
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSalesReturns();
  }

  Future<void> _fetchSalesReturns() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      SalesProvider salesProvider =
          Provider.of<SalesProvider>(context, listen: false);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      await salesProvider.fetchSalesReturn(
          accessToken: accessToken ?? "",
          page: currentPage);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _searchSalesReturns(int page) async {
    try {
      SalesProvider salesProvider =
          Provider.of<SalesProvider>(context, listen: false);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      await salesProvider.fetchSalesReturn(
          accessToken: accessToken ?? "", page: page);

      setState(() {
        currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      // debugPrint(e.toString());
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
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(1),
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
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
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
      (sum, item) => sum + (item.quantity is int ? item.quantity as int : (item.quantity as double).toInt()),
    );
    
    return TableRow(
      children: [
        _buildTableCell(order.order?.orderNumber ?? order.orderId.toString()),
        _buildTableCell(totalQuantity.toString()),
        _buildTableCell(order.totalAmount),
        _buildTableCell(order.status.toString(), isStatusCell: true),
        _buildTableCell(DateHelper.formatISODate(order.createdAt.toString())),
        TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Center(
                child: BuildBoxShadowContainer(
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
              ),
            )),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isStatusCell = false}) {
    if (isStatusCell) {
      IconData iconData;
      Color iconColor;

      if (text == '1') {
        // Approved status
        iconData = Icons.check_circle;
        iconColor = Colors.green;
      } else if (text == '0') {
        // Pending status - show red X
        iconData = Icons.cancel;
        iconColor = Colors.red;
      } else {
        // Default case (rejected or unknown)
        iconData = Icons.cancel;
        iconColor = Colors.red;
      }

      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Center(
            child: Icon(
              iconData,
              color: iconColor,
              size: 20,
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
              FontSize.s9,
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
