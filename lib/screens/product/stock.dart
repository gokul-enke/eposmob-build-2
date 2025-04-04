import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';

import '../../models/list_stock.dart';
import '../../providers/auth_model.dart';
import '../../providers/grid_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final TextEditingController stockNameController = TextEditingController();
  ListStockModelData? selectedStock;
  bool initLoading = false;

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      GridSelectionProvider categoryProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);

      await categoryProvider.listSTockAPI(
        accessToken: accessToken ?? "",
        page: 1,
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchStocks(page) async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      GridSelectionProvider stockProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);

      await stockProvider.listSTockAPI(
        accessToken: accessToken ?? "",
        filterName: stockNameController.text,
        page: page,
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      stockNameController.clear();
    });
    loadInitData();
  }

  void _showStockDetails(ListStockModelData stock) {
    setState(() {
      selectedStock = stock;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Details',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow('Product Name', stock.productName ?? 'N/A'),
                    _buildDetailRow('Store Name', stock.storeName ?? 'N/A'),
                    _buildDetailRow('Quantity', stock.qty?.toString() ?? 'N/A'),
                    _buildDetailRow('Unit', stock.unit ?? 'N/A'),
                    _buildDetailRow(
                        'Retail Price', stock.retailPrice?.toString() ?? 'N/A'),
                    _buildDetailRow('Wholesale Price',
                        stock.wholesalePrice?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Close",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
            color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Product Stock List",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        SizedBox(
                          width: isSmallScreen
                              ? size.width * 0.8
                              : size.width * 0.3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Stock Name ",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                width: isSmallScreen
                                    ? size.width * 0.8
                                    : size.width * 0.3,
                                onchanged: (value) {},
                                controller: stockNameController,
                                size: size,
                                hintText: 'Stock Name',
                              ),
                            ],
                          ),
                        ),
                        CustomRoundButton(
                          title: "Search",
                          fct: () => {searchStocks(1)},
                          height: 45,
                          width: isSmallScreen
                              ? size.width * 0.4
                              : size.width * 0.15,
                          fontSize: FontSize.s12,
                        ),
                        CustomRoundButton(
                          title: "Reset",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          fct: resetSearch,
                          height: 45,
                          width: isSmallScreen
                              ? size.width * 0.4
                              : size.width * 0.15,
                          fontSize: FontSize.s12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: initLoading
                          ? const Center(
                              child: CircularProgressIndicator.adaptive())
                          : Consumer<GridSelectionProvider>(
                              builder: (context, gridProvider, child) {
                                List<ListStockModelData>?
                                    listStockModelDataList =
                                    gridProvider.getListStockModelDataList;

                                if (listStockModelDataList == null ||
                                    listStockModelDataList.isEmpty) {
                                  return const Center(
                                      child: Text("No stock data available"));
                                }

                                return BuildBoxShadowContainer(
                                  margin: const EdgeInsets.only(top: 5),
                                  circleRadius: 7,
                                  offsetValue: const Offset(2, 2),
                                  blurRadius: 8.0,
                                  color: Colors.white,
                                  child: Column(
                                    children: [
                                      // Fixed table header
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: ColorManager.tableBGColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              offset: Offset(0, 2),
                                              blurRadius: 2.0,
                                            ),
                                          ],
                                        ),
                                        child: Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(0.5), // No
                                            1: FlexColumnWidth(
                                                2.0), // Product Name
                                            2: FlexColumnWidth(
                                                2.0), // Store Name
                                            3: FlexColumnWidth(0.8), // Quantity
                                            4: FlexColumnWidth(0.8), // Unit
                                            5: FlexColumnWidth(
                                                1.2), // Retail Price
                                            6: FlexColumnWidth(
                                                1.2), // Wholesale Price
                                            7: FlexColumnWidth(1.0), // Action
                                          },
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                _buildTableHeader('No'),
                                                _buildTableHeader(
                                                    'Product Name'),
                                                _buildTableHeader('Store Name'),
                                                _buildTableHeader('Quantity'),
                                                _buildTableHeader('Unit'),
                                                _buildTableHeader(
                                                    'Retail Price'),
                                                _buildTableHeader(
                                                    'Wholesale Price'),
                                                _buildTableHeader('Action'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Scrollable table body
                                      Expanded(
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: ScrollConfiguration(
                                            behavior:
                                                ScrollConfiguration.of(context)
                                                    .copyWith(
                                              dragDevices: {
                                                PointerDeviceKind.mouse,
                                                PointerDeviceKind.touch,
                                                PointerDeviceKind.stylus,
                                                PointerDeviceKind.trackpad,
                                              },
                                            ),
                                            child: SingleChildScrollView(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              scrollDirection: Axis.vertical,
                                              child: Table(
                                                columnWidths: const {
                                                  0: FlexColumnWidth(0.5), // No
                                                  1: FlexColumnWidth(
                                                      2.0), // Product Name
                                                  2: FlexColumnWidth(
                                                      2.0), // Store Name
                                                  3: FlexColumnWidth(
                                                      0.8), // Quantity
                                                  4: FlexColumnWidth(
                                                      0.8), // Unit
                                                  5: FlexColumnWidth(
                                                      1.2), // Retail Price
                                                  6: FlexColumnWidth(
                                                      1.2), // Wholesale Price
                                                  7: FlexColumnWidth(
                                                      1.0), // Action
                                                },
                                                border: null,
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                children: [
                                                  // Table Rows
                                                  ...listStockModelDataList
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final int index = entry.key;
                                                    final stock = entry.value;
                                                    return TableRow(
                                                      decoration: BoxDecoration(
                                                        color: index % 2 == 0
                                                            ? Colors.white
                                                            : Colors.grey
                                                                .withOpacity(
                                                                    0.1),
                                                      ),
                                                      children: [
                                                        _buildTableCell(
                                                            '${index + 1}'),
                                                        _buildTableCell(
                                                            '${stock.productName}'),
                                                        _buildTableCell(
                                                            '${stock.storeName}'),
                                                        _buildTableCell(
                                                            '${stock.qty}'),
                                                        _buildTableCell(
                                                            '${stock.unit}'),
                                                        _buildTableCell(
                                                            '${stock.retailPrice}'),
                                                        _buildTableCell(
                                                            '${stock.wholesalePrice}'),
                                                        Center(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(8.0),
                                                            child:
                                                                BuildBoxShadowContainer(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5,
                                                                      right: 5),
                                                              circleRadius: 5,
                                                              child: IconButton(
                                                                icon: Icon(
                                                                  Icons
                                                                      .visibility,
                                                                  size: 18,
                                                                  color: ColorManager
                                                                      .kPrimaryColor
                                                                      .withOpacity(
                                                                          0.9),
                                                                ),
                                                                onPressed: () =>
                                                                    _showStockDetails(
                                                                        stock),
                                                                constraints:
                                                                    const BoxConstraints(
                                                                  minWidth: 36,
                                                                  minHeight: 36,
                                                                ),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    PaginationControl(
                      currentPage: Provider.of<GridSelectionProvider>(context,
                              listen: true)
                          .stockCurrentPage,
                      totalPages: Provider.of<GridSelectionProvider>(context,
                              listen: true)
                          .stockTotalPages,
                      onPageChanged: (int page) {
                        searchStocks(page);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
