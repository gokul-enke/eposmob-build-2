import 'package:flutter/material.dart';

import '../../components/build_container_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/custom_icons.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchTextController = TextEditingController();
    Size size = MediaQuery.of(context).size;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              "Transactions ",
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: size.height * 0.07,
                    width: size.width * 0.5,
                    child: TextField(
                      cursorColor: ColorManager.kPrimaryColor,
                      controller: searchTextController,
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Search Customers.....",
                          hintStyle: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.18, ColorManager.textColor),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.black,
                            size: 35,
                          ),
                          prefixIconColor: Colors.black),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      height: size.height * 0.04,
                      width: size.width * 0.09,
                      //margin: const EdgeInsets.only(right: 20),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: ColorManager.boxShadowColor,
                            blurRadius: 6,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                              visualDensity: const VisualDensity(
                                  horizontal: 0, vertical: 0),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {},
                              icon: const Icon(
                                CustomIcons.iconFilterList,
                                color: Colors.black,
                                size: 10,
                              )),
                          Text(
                            "Filters",
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s12,
                              0.27,
                              Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 30.0, right: 30.0),
              child: Divider(thickness: 2),
            ),
            const SizedBox(height: 40),
            BuildBoxShadowContainer(
              circleRadius: 7,
              margin: const EdgeInsets.only(left: 30.0, right: 30.0),
              offsetValue: const Offset(1, 1),
              child: Table(
                columnWidths: const {
                  0: FractionColumnWidth(0.2),
                  1: FractionColumnWidth(0.2),
                  2: FractionColumnWidth(0.2),
                  3: FractionColumnWidth(0.4),
                },
                border: const TableBorder.symmetric(
                    outside: BorderSide.none,
                    inside: BorderSide(
                        color: ColorManager.tableBOrderColor, width: 0.8)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                      decoration:
                          const BoxDecoration(color: ColorManager.tableBGColor),
                      children: [
                        TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                  child: Text(
                                "Customer Name",
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
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                  child: Text(
                                "Amount",
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
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                  child: Text(
                                "Date",
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
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                  child: Text(
                                "Payment Mode( UPI/Card/Cash)",
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.18,
                                  ColorManager.kPrimaryColor,
                                ),
                              )),
                            )),
                      ]),
                  ...List.generate(
                    5,
                    (index) => TableRow(
                      children: [
                        TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.all(35.0),
                              child: Center(
                                child: Text(
                                  "Iris Watson",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
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
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Text(
                                  "\$115.00",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
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
                              padding: const EdgeInsets.all(8.0),
                              child: Center(
                                child: Text(
                                  "15/10/2022",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s9,
                                    0.13,
                                    Colors.black,
                                  ),
                                ),
                              ),
                            )),
                        index % 2 != 0
                            ? TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Text(
                                      "Card",
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s9,
                                        0.13,
                                        ColorManager.kPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ))
                            : TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Text(
                                      "UPI",
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s9,
                                        0.13,
                                        ColorManager.kPrimaryColor,
                                      ),
                                    ),
                                  ),
                                )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ));
  }
}
