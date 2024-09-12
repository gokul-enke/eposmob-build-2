import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class AccountBookScreen extends StatefulWidget {
  const AccountBookScreen({super.key});

  @override
  State<AccountBookScreen> createState() => _AccountBookScreenState();
}

class _AccountBookScreenState extends State<AccountBookScreen> {
  final TextEditingController customerController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
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

      await reportsProvider.fetchCustomerAccountBook(
        accessToken: accessToken ?? "",
      );
    } catch (error) {
      debugPrint(error.toString());
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

      await reportsProvider.fetchCustomerAccountBook(
        accessToken: accessToken ?? "",
        customerName: customerController.text,
        fromDate: fromDateController.text,
        toDate: toDateController.text,
        amount: amountController.text,
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
      customerController.clear();
      amountController.clear();
      fromDateController.clear();
      toDateController.clear();
    });
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    // String? token = Provider.of<AuthModel>(context, listen: false).token;
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
                "Customer Account Book",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
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
                        buildColumnWidgetForTextFields(
                          height: 45,
                          width: 120,
                          onchanged: (value) {},
                          controller: customerController,
                          size: size,
                          hintText: 'Customer Name',
                        ),
                      ],
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
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          margin: const EdgeInsets.only(left: 8),
                          height: 45,
                          width: 150, //size.width * 0.5,
                          child: CalendarPickerTableCell(
                            onDateSelected: (date) {
                              debugPrint(date.toString());
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
                  ],
                ),
              ),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
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
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          margin: const EdgeInsets.only(left: 8),
                          height: 45,
                          width: 150, //size.width * 0.5,
                          child: Container(
                            height: size.height * .06,
                            width: size.width / 4.3,
                            margin: const EdgeInsets.only(left: 8),
                            child: CalendarPickerTableCell(
                              onDateSelected: (date) {
                                debugPrint(date.toString());
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
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Amount ",
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
                            controller: amountController,
                            size: size,
                            hintText: 'Amount',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 35),
                      child: Column(
                        children: [
                          CustomRoundButton(
                            title: "Search",
                            fct: searchAccountBook,
                            height: 45,
                            width: size.width * 0.09,
                            fontSize: FontSize.s12,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 35),
                      child: Column(
                        children: [
                          CustomRoundButton(
                            title: "Reset",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: resetSearch,
                            height: 45,
                            width: size.width * 0.09,
                            fontSize: FontSize.s12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Padding(
              //   padding: const EdgeInsets.only(top: 18.0),
              //   child: Text(
              //     "Customer Account Book",
              //     style: buildCustomStyle(FontWeightManager.semiBold,
              //         FontSize.s20, 0.30, ColorManager.textColor),
              //   ),
              // ),
              // const Divider(thickness: 0.5),
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
                    6: FractionColumnWidth(0.10),
                  },
                  border: TableBorder.symmetric(
                      outside: const BorderSide(
                          color: ColorManager.tableBOrderColor, width: 0.3),
                      inside: const BorderSide(
                          color: ColorManager.tableBOrderColor, width: 0.8)),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: ColorManager.tableBGColor),
                      children: [
                        _buildTableHeader("No"),
                        _buildTableHeader("Customer Name"),
                        _buildTableHeader("Debit Amount"),
                        _buildTableHeader("Credit Amount"),
                        _buildTableHeader("Balance Amount"),
                        _buildTableHeader("Date"),
                        _buildTableHeader("Action"),
                      ],
                    ),
                    if (reportsProvider.customerAccountBook != null)
                      ...reportsProvider.customerAccountBook!.data.data
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            _buildTableCell("${index + 1}"),
                            _buildTableCell(item.customerName),
                            _buildTableCell(item.totalDebit),
                            _buildTableCell(item.totalCredit),
                            _buildTableCell(
                                AmountHelper.formatAmount(item.balanceAmount)
                                    .toString()),
                            _buildTableCell(item.createdAt),
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
