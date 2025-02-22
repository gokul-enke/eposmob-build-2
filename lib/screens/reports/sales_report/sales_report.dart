import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_border.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final TextEditingController customerController = TextEditingController();
  final TextEditingController createdByController = TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();

  SideBarController sideBarController = Get.put(SideBarController());
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
      ReportsProvider reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);

      await reportsProvider.fetchSalesReport(
        accessToken: accessToken ?? "",
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchAccountBook() async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      ReportsProvider reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);

      await reportsProvider.fetchSalesReport(
        accessToken: accessToken ?? "",
        customerName: customerController.text,
        startDate: fromDateController.text,
        endDate: toDateController.text,
        createdBy: createdByController.text,
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
      customerController.clear();
      createdByController.clear();
      fromDateController.clear();
      toDateController.clear();
    });
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    ReportsProvider reportsProvider = Provider.of<ReportsProvider>(context);
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
              Text(
                "Customer Sales Report ",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
              const SizedBox(
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Customer ",
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 45,
                            width: 120, //size.width * 0.5,
                            child: TextFormField(
                              onChanged: (value) {
                                setState(() {
                                  // searchAmount = value;
                                });
                              },
                              cursorColor: ColorManager.kPrimaryColor,
                              cursorHeight: 13,
                              controller: customerController,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: decoration.copyWith(
                                  hintText: "Customer Name   ",
                                  hintStyle: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s10,
                                      0.18,
                                      ColorManager.textColor),
                                  // prefixIcon: const Icon(
                                  //   Icons.search,
                                  //   color: Colors.black,
                                  //   size: 35,
                                  // ),
                                  prefixIconColor: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Created By ",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 45,
                              width: 120, //size.width * 0.5,
                              child: TextFormField(
                                onChanged: (value) {
                                  setState(() {
                                    // searchAmount = value;
                                  });
                                },
                                cursorColor: ColorManager.kPrimaryColor,
                                cursorHeight: 13,
                                controller: createdByController,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.18,
                                    ColorManager.textColor),
                                decoration: decoration.copyWith(
                                    hintText: "Created By    ",
                                    hintStyle: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s10,
                                        0.18,
                                        ColorManager.textColor),
                                    // prefixIcon: const Icon(
                                    //   Icons.search,
                                    //   color: Colors.black,
                                    //   size: 35,
                                    // ),
                                    prefixIconColor: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "From Date ",
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          BuildBorderContainer(
                            margin: const EdgeInsets.only(left: 8),
                            height: 45,
                            width: 150, //size.width * 0.5,
                            child: CalendarPickerTableCell(
                              onDateSelected: (date) {
                                // debugPrint(date.toString());
                                fromDateController.text =
                                    DateFormat('yyyy-MM-dd').format(date);
                                debugPrint(DateFormat('yyyy-MM-dd')
                                    .format(date)
                                    .toString());
                              },
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "To Date ",
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          BuildBorderContainer(
                            margin: const EdgeInsets.only(left: 8),
                            height: 45,
                            width: 150, //size.width * 0.5,
                            child: Container(
                              height: size.height * .06,
                              width: size.width / 4.3,
                              margin: const EdgeInsets.only(left: 8),
                              child: CalendarPickerTableCell(
                                onDateSelected: (date) {
                                  // debugPrint(date.toString());
                                  toDateController.text =
                                      DateFormat('yyyy-MM-dd').format(date);
                                  debugPrint(DateFormat('yyyy-MM-dd')
                                      .format(date)
                                      .toString());
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0, top: 30),
                        child: CustomRoundButton(
                          title: "Search",
                          fct: searchAccountBook,
                          height: 50,
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
                          height: 50,
                          width: size.width * 0.09,
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18.0),
                child: Text(
                  "Customer Sales Report   ",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ),
              const Divider(
                thickness: 0.5,
              ),
              BuildBoxShadowContainer(
                margin: const EdgeInsets.only(top: 20),
                circleRadius: 7,
                offsetValue: const Offset(1, 1),
                child: Table(
                  columnWidths: const {
                    0: FractionColumnWidth(0.06),
                    1: FractionColumnWidth(0.15),
                    2: FractionColumnWidth(0.15),
                    3: FractionColumnWidth(0.15),
                    4: FractionColumnWidth(0.15),
                    5: FractionColumnWidth(0.15),
                  },
                  border: const TableBorder.symmetric(
                      outside: BorderSide(
                          color: ColorManager.tableBOrderColor, width: 0.3),
                      inside: BorderSide(
                          color: ColorManager.tableBOrderColor, width: 0.8)),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: ColorManager.tableBGColor),
                      children: [
                        _buildTableHeader("No"),
                        _buildTableHeader("Customer Name"),
                        _buildTableHeader("Created By"),
                        _buildTableHeader("Price"),
                        _buildTableHeader("Date"),
                        _buildTableHeader("Action"),
                      ],
                    ),
                    if (reportsProvider.salesReport != null)
                      ...reportsProvider.salesReport!.data
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            _buildTableCell("${index + 1}"),
                            _buildTableCell(item.customerName),
                            _buildTableCell(item.createdBy),
                            _buildTableCell(
                                AmountHelper.formatAmount(item.totalPrice)
                                    .toString()),
                            _buildTableCell(item.date),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Center(
                                  child: BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        left: 5, right: 5),
                                    circleRadius: 5,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.visibility,
                                        size: 18,
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.9),
                                      ),
                                      onPressed: () {
                                        // Implement view action
                                      },
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
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
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
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
}
