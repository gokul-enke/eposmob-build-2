import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:web_date_picker/web_date_picker.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final TextEditingController amountRefController = TextEditingController();
  //final TextEditingController dateController = TextEditingController();
  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  List<ListTransaction>? listTransaction = [];
  String searchAmount = '';
  String searchDate = '';
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
      InvoiceProvider invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      await invoiceProvider
          .listAllTransaction(type: null, accessToken: accessToken ?? "")
          .then((value) {
        if (value['status'] == 'success') {
          ListTransactionModel listTransactionModel =
              ListTransactionModel.fromJson(value);
          listTransaction = listTransactionModel.data?.transactions ?? [];
        } else {
          showScaffold(context: context, message: "Data Not Found");
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    InvoiceProvider invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
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
                "Location Management ",
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
                              "State ",
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
                                  searchAmount = value;
                                });
                              },
                              cursorColor: ColorManager.kPrimaryColor,
                              cursorHeight: 13,
                              controller: amountRefController,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: decoration.copyWith(
                                  hintText: "State    ",
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
                                "District ",
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
                                    searchAmount = value;
                                  });
                                },
                                cursorColor: ColorManager.kPrimaryColor,
                                cursorHeight: 13,
                                controller: amountRefController,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.18,
                                    ColorManager.textColor),
                                decoration: decoration.copyWith(
                                    hintText: "District    ",
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
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Pincode ",
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
                                    searchAmount = value;
                                  });
                                },
                                cursorColor: ColorManager.kPrimaryColor,
                                cursorHeight: 13,
                                controller: amountRefController,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.18,
                                    ColorManager.textColor),
                                decoration: decoration.copyWith(
                                    hintText: "Pincode    ",
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
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Location Name ",
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
                              width: 150, //size.width * 0.5,
                              child: TextFormField(
                                onChanged: (value) {
                                  setState(() {
                                    searchAmount = value;
                                  });
                                },
                                cursorColor: ColorManager.kPrimaryColor,
                                cursorHeight: 13,
                                controller: amountRefController,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.18,
                                    ColorManager.textColor),
                                decoration: decoration.copyWith(
                                    hintText: "Location Name    ",
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
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0, top: 30),
                        child: CustomRoundButton(
                          title: "Search",
                          fct: () async {},
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
                          fct: () async {
                            amountRefController.clear();
                            setState(() {
                              searchAmount = '';
                            });
                            // sideBarController.index.value = 22;
                          },
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
                  "Location Management   ",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ),
              const Divider(
                thickness: 0.5,
              ),
              BuildBoxShadowContainer(
                  // height: size.height, //120,
                  margin: const EdgeInsets.only(top: 20),
                  circleRadius: 7,
                  offsetValue: const Offset(1, 1),
                  child: Table(
                    columnWidths: const {
                      0: FractionColumnWidth(0.06),
                      1: FractionColumnWidth(0.06),
                      2: FractionColumnWidth(0.06),
                      3: FractionColumnWidth(0.06),
                      4: FractionColumnWidth(0.06),
                      5: FractionColumnWidth(0.05),
                    },
                    border: TableBorder.symmetric(
                        outside: const BorderSide(
                            color: ColorManager.tableBOrderColor, width: 0.3),
                        inside: const BorderSide(
                            color: ColorManager.tableBOrderColor, width: 0.8)),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
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
                                    TableCellVerticalAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Center(
                                      child: Text(
                                    "Type",
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
                                  padding: const EdgeInsets.all(15.0),
                                  child: Center(
                                      child: Text(
                                    "Status",
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
                      ...listTransaction!.where((transaction) {
                        return transaction.amount!.contains(searchAmount);
                        //&&
                        //  transaction.date.contains(searchDate);
                      }).map((transaction) {
                        String? userName = invoiceProvider
                            .getUserUpOnId(transaction.orderId ?? 1);

                        // String? invoiceAccountType =
                        //     invoiceProvider.getInvoiceNameUpOnId(
                        //         transaction.accountId ?? 1,
                        //         transaction.type ?? "");
                        return TableRow(
                          children: [
                            TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Center(
                                    child: Text(
                                      userName ?? "",
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
                                      "${transaction.type}",
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
                                      "${transaction.amount}",
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
                                      "${transaction.status}",
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
                                            margin: const EdgeInsets.only(
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
                                                invoiceProvider
                                                    .callDetailsOfTransaction(
                                                        id: transaction.id ?? 0,
                                                        accessToken:
                                                            token ?? "");
                                                sideBarController.index.value =
                                                    30;
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
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
