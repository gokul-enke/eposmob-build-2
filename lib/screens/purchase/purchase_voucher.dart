import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/list_purchase_voucher.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';

import '../../providers/purchase_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class PurchaseVoucherScreen extends StatefulWidget {
  const PurchaseVoucherScreen({super.key});

  @override
  State<PurchaseVoucherScreen> createState() => _PurchaseVoucherScreenState();
}

class _PurchaseVoucherScreenState extends State<PurchaseVoucherScreen> {
  bool initLoading = false;
  List<VoucherModelData>? voucherModelListData = [];
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  DateTime? selectedDate;
  GetStoreModelData? storeSelected;

  @override
  void initState() {
    getData();
    super.initState();
  }

  getData() async {
    setState(() {
      initLoading = true;
    });
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    await purchaseProvider
        .listPurchaseVoucher(accessToken: accessToken ?? "", page: 1)
        .then((value) async {});
    voucherModelListData = purchaseProvider.getVoucherModelDataList;
    setState(() {
      initLoading = false;
    });
  }

  // Search purchases
  Future<void> searchPurchaseVoucher(int page) async {
    // debugPrint("Purchase Voucher Search Called");
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      PurchaseProvider purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);

      await purchaseProvider.listPurchaseVoucher(
        accessToken: accessToken ?? "",
        filterAmount: amountController.text,
        filterStore: storeController.text,
        // filterDate: DateHelper.formatDate(selectedDate!),
        page: page,
      );

      // debugPrint(purchaseProvider.getVoucherDetailsList!.length.toString());
      setState(() {
        voucherModelListData = purchaseProvider.getVoucherModelDataList;
      });
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  // Reset search inputs
  void resetSearch() {
    getData();
    setState(() {
      storeController.clear();
      selectedDate = null;
      amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    SideBarController sideBarController = Get.put(SideBarController());
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;
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
                "Voucher List",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
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
                    // Store
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Store",
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
                            width: 150,
                            child: BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 0),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width / 4.5,
                              child: DropdownButtonFormField<GetStoreModelData>(
                                decoration: const InputDecoration(
                                  border:
                                      InputBorder.none, // Remove the underline
                                ),
                                value: storeSelected,
                                hint: Text(
                                  'Select Store',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                ),
                                items:
                                    storeList!.map((GetStoreModelData store) {
                                  return DropdownMenuItem<GetStoreModelData>(
                                      value: store,
                                      child: Text(
                                        store.name ?? '',
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ));
                                }).toList(),
                                onChanged: (GetStoreModelData? storeModelData) {
                                  if (storeModelData != null) {
                                    // Update the selected category in the provider
                                    setState(() {
                                      storeSelected = storeModelData;
                                      storeController.text =
                                          "${storeModelData.id ?? 1}";
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Date",
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
                            height: 45,
                            width: 150,
                            child: Center(
                              child: CalendarPickerTableCell(
                                onDateSelected: (DateTime date) {
                                  selectedDate = date;
                                },
                              ),
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
                              "Amount",
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
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Search",
                        fct: () {
                          searchPurchaseVoucher(1);
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
              BuildBoxShadowContainer(
                  // height: size.height, //120,
                  margin: const EdgeInsets.only(top: 20),
                  circleRadius: 7,
                  offsetValue: const Offset(1, 1),
                  child: initLoading
                      ? Table(
                          columnWidths: const {
                            0: FractionColumnWidth(0.01),
                            1: FractionColumnWidth(0.06),
                            2: FractionColumnWidth(0.06),
                            3: FractionColumnWidth(0.06),
                            4: FractionColumnWidth(0.06),
                            5: FractionColumnWidth(0.06),
                            6: FractionColumnWidth(0.05),
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
                                          "Purchase Date",
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
                                          "Store",
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
                                          "Supplier",
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
                          ])
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: size.width * 1,
                            child: Table(
                              columnWidths: const {
                                0: FractionColumnWidth(0.01),
                                1: FractionColumnWidth(0.06),
                                2: FractionColumnWidth(0.06),
                                3: FractionColumnWidth(0.06),
                                4: FractionColumnWidth(0.06),
                                5: FractionColumnWidth(0.06),
                                6: FractionColumnWidth(0.05),
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
                                              "Purchase Date",
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
                                              "Store",
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
                                              "SUpplier",
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
                                ...voucherModelListData!
                                    .where((transaction) {
                                      return transaction.purchaseDate!.contains(
                                              searchTextController.text) ||
                                          transaction.amountTotal
                                              .toString()
                                              .contains(
                                                  searchTextController.text);
                                    })
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      int index = entry.key;
                                      var voucher = entry.value;
                                      String store = purchaseProvider.storeName(
                                              voucher.storeId ?? 1) ??
                                          '';
                                      String supplier =
                                          purchaseProvider.supplierName(
                                                  voucher.supplierId ?? 1) ??
                                              '';
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
                                                    (index + 1).toString(),
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
                                                    voucher.purchaseDate ?? "",
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
                                                    store,
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
                                                    supplier,
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
                                                    "${voucher.amountTotal}",
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
                                                              purchaseProvider
                                                                  .callVoucherDetails(
                                                                      voucherId:
                                                                          voucher.id ??
                                                                              0,
                                                                      purchaseId:
                                                                          voucher.purchaseId ??
                                                                              0);
                                                              sideBarController
                                                                  .index
                                                                  .value = 29;
                                                            },
                                                          )),
                                                      BuildBoxShadowContainer(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5),
                                                          color: ColorManager
                                                              .kPrimaryColor
                                                              .withOpacity(0.9),
                                                          circleRadius: 5,
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.add,
                                                              size: 18,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            onPressed: () {
                                                              purchaseProvider
                                                                  .callVoucherDetails(
                                                                      voucherId:
                                                                          voucher.id ??
                                                                              0,
                                                                      purchaseId:
                                                                          voucher.purchaseId ??
                                                                              0);
                                                              sideBarController
                                                                  .index
                                                                  .value = 37;
                                                            },
                                                          )),
                                                    ],
                                                  ),
                                                ),
                                              )),
                                        ],
                                      );
                                    })
                                    .toList(),
                              ],
                            ),
                          ),
                        )),
              PaginationControl(
                currentPage:
                    Provider.of<PurchaseProvider>(context, listen: true)
                        .purchaseVoucherCurrentPage,
                totalPages: Provider.of<PurchaseProvider>(context, listen: true)
                    .purchaseVoucherTotalPages,
                onPageChanged: (int page) {
                  searchPurchaseVoucher(page);
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
