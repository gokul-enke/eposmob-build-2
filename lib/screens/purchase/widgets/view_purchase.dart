import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_detail_row.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/list_purchase.dart';

import '../../../providers/grid_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewPurchaseWidget extends StatelessWidget {
  const ViewPurchaseWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
    PurchaseProvider purchaseProvider = Provider.of<PurchaseProvider>(context);

    final ListPurchaseModelData? purchaseDetails =
        purchaseProvider.getListPurchaseModelDataDetails;

    VoucherDetail? voucherDetails = purchaseProvider.getVoucherDetails;
    List<PurchaseItem>? listPurchaseItems =
        purchaseProvider.getlistPurchaseItemView;

    // debugPrintdebugPrint("purchaseDetails: ${purchaseDetails?.purchaserId.toString()}");

    String store = purchaseProvider.storeName(
            voucherDetails == null ? 1 : voucherDetails.storeId ?? 1) ??
        '';
    String supplier = purchaseProvider.supplierName(
            voucherDetails == null ? 1 : voucherDetails.supplierId ?? 1) ??
        '';

    // Filter listPurchaseItems based on purchaseId in voucherDetails
    List<PurchaseItem>? filteredItems = listPurchaseItems?.where((item) {
      return item.purchaseId == voucherDetails?.purchaseId;
    }).toList();

    // Filter listPurchaseItems based on purchaseId in voucherDetails
    List<PurchaseItem>? filteredPurchaseData = listPurchaseItems?.where((item) {
      return item.purchaseId == voucherDetails?.purchaseId;
    }).toList();

    debugPrint(
        voucherDetails == null ? "viewCategory" : voucherDetails.purchaseDate);
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
            CustomBackButton(
              onPressed: () {
                sideBarController.index.value = 19;
              },
              text: 'All Purchases',
              // Optionally, you can customize the color and size
              // color: ColorManager.customColor,
              // size: 20.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Show Purchase",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
                BuildBoxShadowContainer(
                  width: 15,
                  height: 15,
                  circleRadius: 10,
                  color: ColorManager.kPrimaryColor,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        sideBarController.index.value = 19;
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 10,
                        color: Colors.white,
                      )),
                )
              ],
            ),
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: ColorManager.kPrimaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              padding: const EdgeInsets.only(
                left: 20,
                top: 20,
              ),
              margin: const EdgeInsets.only(
                  top: 20, bottom: 0, left: 10, right: 10),
              child: Text(
                "Show Purchase",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s15, 0.30, Colors.white),
              ),
            ),
            BuildBoxShadowContainer(
                height: size.height, //120,
                margin: const EdgeInsets.only(
                    top: 0, bottom: 10, left: 10, right: 10),
                padding: const EdgeInsets.only(
                    top: 10, bottom: 10, left: 10, right: 10),
                circleRadius: 7,
                offsetValue: const Offset(1, 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BuildDetailRow(
                      title1: "Purchaser Name",
                      content1: "Sales Executive",
                      title2: "Purchaser Date",
                      content2: voucherDetails?.purchaseDate ?? "",
                    ),
                    BuildDetailRow(
                      title1: "Number Of Items",
                      content1: filteredItems?.length.toString() ?? "0",
                      title2: "Total Amount",
                      content2: purchaseDetails!.amountTotal.toString(),
                    ),
                    BuildDetailRow(
                      title1: "Status",
                      content1: _getStatus(purchaseDetails.status.toString()),
                      title2: "Currency",
                      content2: purchaseDetails.currency ??
                          "Default Currency", // Replace with default currency if not available
                    ),
                    BuildBoxShadowContainer(
                        height: size.height / 2.5, //120,
                        width: size.width,
                        margin: const EdgeInsets.only(top: 20),
                        circleRadius: 7,
                        offsetValue: const Offset(1, 1),
                        child: SingleChildScrollView(
                          child: Table(
                            columnWidths: const {
                              0: FractionColumnWidth(0.01),
                              1: FractionColumnWidth(0.04),
                              2: FractionColumnWidth(0.01),
                              3: FractionColumnWidth(0.01),
                              4: FractionColumnWidth(0.03),
                              5: FractionColumnWidth(0.03),
                              6: FractionColumnWidth(0.03),
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
                                            "Unit",
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
                                            "Unit Price",
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
                                    // TableCell(
                                    //     verticalAlignment:
                                    //         TableCellVerticalAlignment.middle,
                                    //     child: Padding(
                                    //       padding: const EdgeInsets.all(15.0),
                                    //       child: Center(
                                    //           child: Text(
                                    //         "Action",
                                    //         style: buildCustomStyle(
                                    //           FontWeightManager.medium,
                                    //           FontSize.s12,
                                    //           0.18,
                                    //           ColorManager.kPrimaryColor,
                                    //         ),
                                    //       )),
                                    //     )),
                                  ]),

                              // Map your order data to table rows here
                              ...filteredItems!.asMap().entries.map((entry) {
                                final products = entry.value;
                                final index = entry.key;
                                String productName = gridSelectionProvider
                                        .productName(products.productId ?? 0) ??
                                    "";

                                String storeName = purchaseProvider
                                        .storeName(products.storeId ?? 1) ??
                                    '';
                                String supplierName =
                                    purchaseProvider.supplierName(
                                            products.supplierId ?? 1) ??
                                        '';
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
                                              productName,
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
                                              "${products.quantity}",
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
                                              "${products.unit}",
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
                                              "${products.unitPrice}",
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
                                              storeName,
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
                                              supplierName,
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
                                    //         child: Row(
                                    //           children: [
                                    //             BuildBoxShadowContainer(
                                    //                 margin:
                                    //                     const EdgeInsets.only(
                                    //                         left: 5, right: 5),
                                    //                 circleRadius: 5,
                                    //                 color: ColorManager
                                    //                     .kPrimaryColor
                                    //                     .withOpacity(0.9),
                                    //                 child: IconButton(
                                    //                   icon: const Icon(
                                    //                     Icons.edit,
                                    //                     size: 18,
                                    //                     color: Colors.white,
                                    //                   ),
                                    //                   onPressed: () async {},
                                    //                 )),
                                    //           ],
                                    //         ),
                                    //       ),
                                    //     )),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        )),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: CustomRoundButton(
                        title: "Back",
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () async {
                          sideBarController.index.value = 19;
                        },
                        height: 50,
                        width: size.width * 0.19,
                        fontSize: FontSize.s12,
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    ));
  }

  String _getStatus(String? status) {
    if (status == "Y") return "Active";
    if (status == "N") return "Inactive";
    return "";
  }
}
