import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';

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
      debugPrint(error.toString());
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
      debugPrint(error.toString());
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

  // loadData() async {
  //   setState(() {
  //     initLoading = true;
  //   });
  //   String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
  //   GridSelectionProvider gridSelectionProvider =
  //       Provider.of<GridSelectionProvider>(context, listen: false);
  //   await gridSelectionProvider.listSTockAPI(accessToken: accessToken ?? '');
  //   setState(() {
  //     initLoading = false;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    SideBarController sideBarController = Get.put(SideBarController());
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
          child: ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Product Stock List",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  CustomRoundButton(
                    title: "Add Product Stock",
                    fct: () {
                      sideBarController.index.value = 18;
                    },
                    fontSize: 12,
                    height: 45,
                    width: 200,
                  ),
                ],
              ),
              const SizedBox(
                height: 15,
              ),
              SizedBox(
                height: 90,
                child: Row(
                  // scrollDirection: Axis.horizontal,
                  // physics: const BouncingScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
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
                            width: 120,
                            onchanged: (value) {},
                            controller: stockNameController,
                            size: size,
                            hintText: 'Stock Name',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Search",
                        fct: () => {searchStocks(1)},
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Reset",
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: resetSearch,
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                  ],
                ),
              ),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.end,
              //   children: [
              //     // Text(
              //     //   "Product Stock List  ",
              //     //   style: buildCustomStyle(FontWeightManager.semiBold,
              //     //       FontSize.s20, 0.30, ColorManager.textColor),
              //     // ),
              //     Row(
              //       mainAxisAlignment: MainAxisAlignment.end,
              //       children: [
              //         // SizedBox(
              //         //   height: 45,
              //         //   width: 180, //size.width * 0.5,
              //         //   child: TextField(
              //         //     cursorColor: ColorManager.kPrimaryColor,
              //         //     cursorHeight: 13,
              //         //     //  controller: searchTextController,
              //         //     onChanged: (value) {
              //         //       Provider.of<GridSelectionProvider>(context,
              //         //               listen: false)
              //         //           .searchStocks(value);
              //         //     },
              //         //     style: buildCustomStyle(FontWeightManager.medium,
              //         //         FontSize.s10, 0.18, ColorManager.textColor),
              //         //     decoration: decoration.copyWith(
              //         //         hintText: "Search    ",
              //         //         hintStyle: buildCustomStyle(
              //         //             FontWeightManager.medium,
              //         //             FontSize.s10,
              //         //             0.18,
              //         //             ColorManager.textColor),
              //         //         // prefixIcon: const Icon(
              //         //         //   Icons.search,
              //         //         //   color: Colors.black,
              //         //         //   size: 35,
              //         //         // ),
              //         //         prefixIconColor: Colors.black),
              //         //   ),
              //         // ),
              //         const SizedBox(
              //           width: 10,
              //         ),
              //         CustomRoundButton(
              //           title: "Add Product Stock",
              //           fct: () {
              //             sideBarController.index.value = 18;
              //           },
              //           fontSize: 12,
              //           height: 45,
              //           width: 200,
              //         ),
              //       ],
              //     ),
              //   ],
              // ),
              initLoading
                  ? SizedBox(
                      height: size.height,
                      child: const Center(
                          child: CircularProgressIndicator.adaptive()))
                  : Consumer<GridSelectionProvider>(
                      builder: (context, gridProvider, child) {
                        List<ListStockModelData>? listStockModelDataList =
                            gridProvider.getListStockModelDataList;

                        return BuildBoxShadowContainer(
                          // height: size.height, //120,
                          margin: const EdgeInsets.only(top: 20),
                          circleRadius: 7,
                          offsetValue: const Offset(1, 1),
                          child: Table(
                            columnWidths: const {
                              0: FractionColumnWidth(0.01),
                              1: FractionColumnWidth(0.04),
                              2: FractionColumnWidth(0.04),
                              3: FractionColumnWidth(0.01),
                              4: FractionColumnWidth(0.04),
                              5: FractionColumnWidth(0.04),
                              6: FractionColumnWidth(0.07),
                            },
                            border: const TableBorder.symmetric(
                                outside: BorderSide(
                                    color: ColorManager.tableBOrderColor,
                                    width: 0.3),
                                inside: BorderSide(
                                    color: ColorManager.tableBOrderColor,
                                    width: 0.8)),
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              TableRow(
                                  decoration: const BoxDecoration(
                                      color: ColorManager.tableBGColor),
                                  children: [
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "No",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "Product Name",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "Store Name",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                    // TableCell(
                                    //     verticalAlignment:
                                    //         TableCellVerticalAlignment.middle,
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.all(15.0),
                                    //       child: Center(
                                    //           child: Text(
                                    //         "User Name",
                                    //         style: buildCustomStyle(
                                    //           FontWeightManager.medium,
                                    //           FontSize.s12,
                                    //           0.18,
                                    //           ColorManager.kPrimaryColor,
                                    //         ),
                                    //       )),
                                    //     )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "Quantity",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "Retail Price",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "Wholesale Price",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                              child: Text(
                                            "Action",
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ColorManager.kPrimaryColor,
                                            ),
                                          )),
                                        )),
                                  ]),

                              // Map your order data to table rows here
                              ...listStockModelDataList!
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final int index = entry.key;
                                final stock = entry.value;
                                return TableRow(
                                  children: [
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Text(
                                              "${index + 1}",
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Text(
                                              "${stock.productName}",
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Text(
                                              "${stock.storeName}",
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        )),
                                    // TableCell(
                                    //     verticalAlignment:
                                    //         TableCellVerticalAlignment.middle,
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.all(15.0),
                                    //       child: Center(
                                    //         child: Text(
                                    //           "${stock.userName}",
                                    //           style: buildCustomStyle(
                                    //             FontWeightManager.medium,
                                    //             FontSize.s9,
                                    //             0.13,
                                    //             Colors.black,
                                    //           ),
                                    //         ),
                                    //       ),
                                    //     )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Text(
                                              "${stock.quantity}",
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Text(
                                              "${stock.retailPrice}",
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Text(
                                              "${stock.wholesalePrice}",
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        )),
                                    TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Center(
                                            child: Row(
                                              children: [
                                                BuildBoxShadowContainer(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 5, right: 5),
                                                    circleRadius: 5,
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.visibility,
                                                        size: 18,
                                                        color: ColorManager
                                                            .kPrimaryColor
                                                            .withOpacity(0.9),
                                                      ),
                                                      onPressed: () {
                                                        gridProvider
                                                            .callStockDetails(
                                                                accessToken:
                                                                    accessToken ??
                                                                        '',
                                                                stockId:
                                                                    stock.id ??
                                                                        0);
                                                        sideBarController
                                                            .index.value = 33;
                                                      },
                                                    )),
                                                // BuildBoxShadowContainer(
                                                //     margin:
                                                //         const EdgeInsets.only(
                                                //             left: 5, right: 5),
                                                //     circleRadius: 5,
                                                //     color: Colors.red
                                                //         .withOpacity(0.9),
                                                //     child: IconButton(
                                                //       icon: const Icon(
                                                //         Icons.delete,
                                                //         size: 18,
                                                //         color: Colors.white,
                                                //       ),
                                                //       onPressed: () {},
                                                //     )),
                                              ],
                                            ),
                                          ),
                                        )),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
              PaginationControl(
                currentPage:
                    Provider.of<GridSelectionProvider>(context, listen: true)
                        .stockCurrentPage,
                totalPages:
                    Provider.of<GridSelectionProvider>(context, listen: true)
                        .stockTotalPages,
                onPageChanged: (int page) {
                  searchStocks(page);
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
