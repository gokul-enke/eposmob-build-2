import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
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
      int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
      await salesProvider.fetchSalesReturn(
          accessToken: accessToken ?? "",
          customerId: customerId!,
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
      int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
      await salesProvider.fetchSalesReturn(
          accessToken: accessToken ?? "", customerId: customerId!, page: page);

      setState(() {
        currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
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
                        ? Container()
                        : _buildSalesReturnTable(salesProvider),
                  ),
                ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomRoundButton(
              title: "Create Sales Return",
              fct: () {
                sideBarController.index.value = 49;
              },
              fontSize: 12,
              height: 45,
              width: 200,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesReturnTable(SalesProvider salesProvider) {
    return Column(
      children: [
        // Table header row
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
            3: FlexColumnWidth(2),
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
                  3: FlexColumnWidth(2),
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
      children: ["No", "Order ID", "Total Return Amount", "Status"]
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
    return TableRow(
      children: [
        _buildTableCell(index.toString()),
        _buildTableCell(order.orderId.toString()),
        _buildTableCell(order.totalAmount),
        _buildTableCell(order.status.toString(), isStatusCell: true),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isStatusCell = false}) {
    if (isStatusCell) {
      IconData iconData;
      Color iconColor;

      if (text == '1') {
        // Approved or success status
        iconData = Icons.check_circle;
        iconColor = Colors.green;
      } else if (text == '0') {
        // Pending or failed status
        iconData = Icons.pending;
        iconColor = Colors.orange;
      } else {
        // Default case
        iconData = Icons.help_outline;
        iconColor = Colors.grey;
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
      currentPage: salesProvider.currentPage,
      totalPages: salesProvider.totalPages,
      onPageChanged: (int page) {
        _searchSalesReturns(page);
      },
    );
  }
}
