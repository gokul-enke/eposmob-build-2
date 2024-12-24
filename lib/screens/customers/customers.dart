import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:provider/provider.dart';

import '../../controllers/sidebar_controller.dart';
import '../../models/customer_list.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool isInitLoading = false;
  List<CustomerListModelData>? customerList = [];
  final customerNameController = TextEditingController();
  final customerEmailController = TextEditingController();
  final customerPhoneController = TextEditingController();
  final customerAgeRangeController = TextEditingController();
  bool initLoading = false;

  @override
  void initState() {
    super.initState();
    getCustomersDetails();
  }

  void getCustomersDetails() async {
    try {
      setState(() {
        isInitLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");
      CustomerProvider()
          .listCustomer(
        accessToken: accessToken ?? "",
        page: 1,
      )
          .then((response) {
        if (response["status"] == "success") {
          CustomerListModel customerListModel =
              CustomerListModel.fromJson(response);

          setState(() {
            customerList = customerListModel.data;
          });
        } else {}
      });
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  void searchCustomer(page) async {
    debugPrint("category search called");
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");
      CustomerProvider()
          .listCustomer(
        accessToken: accessToken ?? "",
        page: 1,
        filterName: customerNameController.text,
        filterEmail: customerEmailController.text,
        filterPhone: customerPhoneController.text,
      )
          .then((response) {
        if (response["status"] == "success") {
          CustomerListModel customerListModel =
              CustomerListModel.fromJson(response);

          setState(() {
            customerList = customerListModel.data;
          });
        }
      });
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
      customerNameController.clear();
      customerEmailController.clear();
      customerPhoneController.clear();
    });
    getCustomersDetails();
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    CustomerProvider customerProvider = Provider.of<CustomerProvider>(context);
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(
          children: [
            Container(
              margin: const EdgeInsets.only(
                  left: 10, top: 20, bottom: 0, right: 10),
              padding: const EdgeInsets.only(
                  left: 10, top: 20, bottom: 0, right: 10),
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
                padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Customers',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                        CustomRoundButtonWithIcon(
                          title: "Add New Customer",
                          fct: () {
                            sideBarController.index.value = 9;
                          },
                          height: 50,
                          width: size.width * 0.19,
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                          ),
                          fontSize: FontSize.s12,
                          size: size,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 90,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Name",
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
                                  controller: customerNameController,
                                  size: size,
                                  hintText: 'Name',
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Email",
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
                                  controller: customerEmailController,
                                  size: size,
                                  hintText: 'Email',
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Phone",
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
                                  controller: customerPhoneController,
                                  size: size,
                                  hintText: 'Phone',
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "Age Range",
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
                                  controller: customerAgeRangeController,
                                  size: size,
                                  hintText: 'Age Range',
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0, top: 30),
                            child: CustomRoundButton(
                              title: "Search",
                              fct: () {
                                searchCustomer(1);
                              },
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
                              fct: () {
                                resetSearch();
                              },
                              height: 45,
                              width: size.width * 0.09,
                              fontSize: FontSize.s12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      child: Column(
                        children: [
                          BuildBoxShadowContainer(
                              width: size.width,
                              margin: const EdgeInsets.only(top: 20),
                              circleRadius: 7,
                              offsetValue: const Offset(1, 1),
                              child: Center(
                                child: Table(
                                  columnWidths: const {
                                    0: FractionColumnWidth(0.10),
                                    1: FractionColumnWidth(0.25),
                                    2: FractionColumnWidth(0.25),
                                    3: FractionColumnWidth(0.25),
                                    4: FractionColumnWidth(0.15),
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Name",
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Email",
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                    child: Text(
                                                  "Phone No.",
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
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
                                    ...customerList!
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      CustomerListModelData customer =
                                          entry.value;
                                      final int index = entry.key;

                                      return TableRow(
                                        children: [
                                          TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                  child: Text(
                                                    customer.name ?? "",
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                  child: Text(
                                                    customer.email ?? "",
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                  child: Text(
                                                    customer.phone ?? "",
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
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(15.0),
                                                child: Center(
                                                  child: Row(
                                                    children: [
                                                      BuildBoxShadowContainer(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5),
                                                          circleRadius: 5,
                                                          child: IconButton(
                                                            icon: Icon(
                                                              Icons.visibility,
                                                              size: 18,
                                                              color: ColorManager
                                                                  .kPrimaryColor
                                                                  .withOpacity(
                                                                      0.9),
                                                            ),
                                                            onPressed: () {
                                                              customerProvider
                                                                  .selectCustomer(
                                                                      customerList![
                                                                          index]);
                                                              sideBarController
                                                                  .index
                                                                  .value = 38;
                                                            },
                                                          )),
                                                    ],
                                                  ),
                                                ),
                                              )),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              )),
                          PaginationControl(
                            currentPage: 1,
                            totalPages: 1,
                            onPageChanged: (int page) {
                              // Handle pagination if needed
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
