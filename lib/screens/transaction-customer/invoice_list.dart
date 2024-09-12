import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';

import '../../models/list_transaction.dart';
import '../../providers/auth_model.dart';

import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class InvoiceListcreen extends StatefulWidget {
  const InvoiceListcreen({super.key});

  @override
  State<InvoiceListcreen> createState() => _InvoiceListcreenState();
}

class _InvoiceListcreenState extends State<InvoiceListcreen> {
  SideBarController sideBarController = Get.put(SideBarController());
  bool initLoading = false;
  final TextEditingController searchTextController = TextEditingController();
  List<ListTransaction>? listTransaction = [];
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
          .listAllTransaction(type: "Cr", accessToken: accessToken ?? "")
          .then((value) {
        if (value['status'] == 'success') {
          ListTransactionModel listTransactionModel =
              ListTransactionModel.fromJson(value);
          listTransaction = listTransactionModel.data ?? [];
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Invoice List",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  CustomRoundButton(
                    title: "Create New Invoice",
                    fct: () {
                      sideBarController.index.value = 24;
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
                              "Name",
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
                            width: 120,
                            child: TextFormField(
                              onChanged: (value) {
                                setState(() {
                                  // Update state if needed
                                });
                              },
                              cursorColor: ColorManager.kPrimaryColor,
                              cursorHeight: 13,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.18,
                                ColorManager.textColor,
                              ),
                              decoration: decoration.copyWith(
                                hintText: "Name",
                                hintStyle: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s10,
                                  0.18,
                                  ColorManager.textColor,
                                ),
                                prefixIconColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Search",
                        fct: (searchAccountBook) {},
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
                        fct: (resetSearch) {},
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                  ],
                ),
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
                                    "Account Type",
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
                                    "Sender",
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
                                    "Beneficiary",
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
                        return transaction.amount!
                            .contains(searchTextController.text);
                      }).map((transaction) {
                        String? userName = invoiceProvider
                            .getUserUpOnId(transaction.userId ?? 1);

                        String? invoiceAccountType =
                            invoiceProvider.getInvoiceNameUpOnId(
                                transaction.accountId ?? 1,
                                transaction.type ?? "");
                        return TableRow(
                          children: [
                            TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Center(
                                    child: Text(
                                      invoiceAccountType ?? "",
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
                                      userName ?? '',
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
                                                    31;
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
