import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/list_purchase.dart';

import '../../../providers/grid_provider.dart';
import '../../../providers/purchase_provider.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class AddVoucherDetailsWidget extends StatelessWidget {
  const AddVoucherDetailsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    if (!canViewPurchasePrice(context)) {
      return SafeArea(
        child: Center(
          child: Text(
            'add_voucher_details.permission_required'.tr,
          ),
        ),
      );
    }
    SideBarController sideBarController = Get.put(SideBarController());
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
    PurchaseProvider purchaseProvider = Provider.of<PurchaseProvider>(context);
    VoucherDetail? voucherDetails = purchaseProvider.getVoucherDetails;
    List<PurchaseItem>? listPurchaseItems =
        purchaseProvider.getlistPurchaseItemView;

    String store = purchaseProvider.storeName(
            voucherDetails == null ? 1 : voucherDetails.storeId ?? 1) ??
        '';
    String supplier = purchaseProvider.supplierName(
            voucherDetails == null ? 1 : voucherDetails.supplierId ?? 1) ??
        '';

    Map<String, String>? unitList = purchaseProvider.getUnitList;

    // Filter listPurchaseItems based on purchaseId in voucherDetails
    List<PurchaseItem>? filteredItems = listPurchaseItems?.where((item) {
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
                sideBarController.index.value = 26;
              },
              text: 'add_voucher_details.btn_all_vouchers'.tr,
              // Optionally, you can customize the color and size
              // color: ColorManager.customColor,
              // size: 20.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'add_voucher_details.page_title'.tr,
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
                'add_voucher_details.section_title'.tr,
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
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_purchase_date'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text: voucherDetails == null
                                      ? ""
                                      : voucherDetails.purchaseDate,
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.semiBold,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_store'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text: voucherDetails == null ? "" : store,
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.semiBold,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_voucher_number'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text: voucherDetails == null
                                      ? ""
                                      : voucherDetails.voucherNumber ?? "",
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.semiBold,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_amount'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text:
                                      "${voucherDetails == null ? "" : voucherDetails.amountTotal}",
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_tax'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text: voucherDetails == null
                                      ? ""
                                      : voucherDetails.taxAmount ?? "",
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.semiBold,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_currency'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text: voucherDetails == null
                                      ? ""
                                      : voucherDetails.currency,
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.semiBold,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'add_voucher_details.label_supplier'.tr,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                                TextSpan(
                                  text: voucherDetails == null ? "" : supplier,
                                  // style: buildCustomStyle(
                                  //     FontWeightManager.semiBold,
                                  //     FontSize.s15,
                                  //     0.30,
                                  //     ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child:
                            Container(), // Empty container to maintain row structure
                      ),
                    ],
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
                            0: FractionColumnWidth(0.05),
                            1: FractionColumnWidth(0.01),
                            2: FractionColumnWidth(0.03),
                            3: FractionColumnWidth(0.05),
                            4: FractionColumnWidth(0.05),
                            5: FractionColumnWidth(0.05),
                            6: FractionColumnWidth(0.07),
                            7: FractionColumnWidth(0.02),
                            8: FractionColumnWidth(0.01),
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
                                          'add_voucher_details.col_product_name'.tr,
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
                                          'add_voucher_details.col_quantity'.tr,
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
                                          'add_voucher_details.col_unit'.tr,
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
                                          'add_voucher_details.col_purchase_rate'.tr,
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
                                          'add_voucher_details.col_retail_price'.tr,
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
                                          'add_voucher_details.col_wholesale_price'.tr,
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
                                          'add_voucher_details.col_expiry_date'.tr,
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
                                          'add_voucher_details.col_batch_no'.tr,
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
                                          'add_voucher_details.col_action'.tr,
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
                            ...filteredItems!.map((products) {
                              String productName = gridSelectionProvider
                                      .productName(products.productId ?? 0) ??
                                  "";

                              // Controllers for form fields
                              TextEditingController quantityController =
                                  TextEditingController(
                                      text:
                                          products.quantity?.toString() ?? '');
                              TextEditingController purchaseRateController =
                                  TextEditingController();
                              TextEditingController retailPriceController =
                                  TextEditingController();
                              TextEditingController wholesalePriceController =
                                  TextEditingController();
                              TextEditingController wholesaleMinUnitController =
                                  TextEditingController();
                              TextEditingController batchNumberController =
                                  TextEditingController();

                              String selectedUnit =
                                  products.unit ?? unitList?.keys.first ?? '';
                              DateTime? selectedDate;

                              return TableRow(
                                children: [
                                  TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.all(15.0),
                                        child: Center(
                                          child: Text(
                                            productName,
                                            textAlign: TextAlign.start,
                                            softWrap: true,
                                            maxLines: 4,
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
                                        child: TextFormField(
                                          controller: quantityController,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(10.0)),
                                            ),
                                            hintStyle:
                                                const TextStyle(fontSize: 10.0),
                                            hintText: 'add_voucher_details.hint_quantity'.tr,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Center(
                                        child: BuildBoxShadowContainer(
                                          circleRadius: 7,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.all(5),
                                          height: size.height * .07,
                                          child:
                                              DropdownButtonFormField<String>(
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                            ),
                                            value: products.unit ??
                                                unitList?.keys.first,
                                            hint: Text(
                                              'add_voucher_details.hint_choose_unit'.tr,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.27,
                                                ColorManager.textColor
                                                    .withOpacity(.5),
                                              ),
                                            ),
                                            icon: const Icon(
                                                Icons.arrow_drop_down,
                                                color:
                                                    ColorManager.kPrimaryColor),
                                            iconSize: 24,
                                            isExpanded: true,
                                            isDense: true,
                                            onChanged: (String? newValue) {
                                              // Handle unit change
                                            },
                                            items:
                                                unitList!.entries.map((entry) {
                                              return DropdownMenuItem<String>(
                                                value: entry.key,
                                                child: Text(
                                                  entry.value,
                                                  style: buildCustomStyle(
                                                    FontWeightManager.medium,
                                                    FontSize.s12,
                                                    0.27,
                                                    ColorManager.textColor
                                                        .withOpacity(.5),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Center(
                                        child: TextFormField(
                                          controller: purchaseRateController,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(10.0)),
                                            ),
                                            hintStyle:
                                                const TextStyle(fontSize: 10.0),
                                            hintText: 'add_voucher_details.hint_purchase_rate'.tr,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Center(
                                        child: TextFormField(
                                          controller: retailPriceController,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(10.0)),
                                            ),
                                            hintStyle:
                                                const TextStyle(fontSize: 10.0),
                                            hintText: 'add_voucher_details.hint_retail_price'.tr,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          TextFormField(
                                            controller:
                                                wholesalePriceController,
                                            decoration: InputDecoration(
                                              border: const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(10.0)),
                                              ),
                                              hintStyle:
                                                  const TextStyle(fontSize: 10.0),
                                              hintText: 'add_voucher_details.hint_wholesale_price'.tr,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          TextFormField(
                                            controller:
                                                wholesaleMinUnitController,
                                            decoration: InputDecoration(
                                              border: const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(10.0)),
                                              ),
                                              hintStyle:
                                                  const TextStyle(fontSize: 10.0),
                                              hintText: 'add_voucher_details.hint_min_unit'.tr,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Center(
                                        child: CalendarPickerTableCell(
                                          onDateSelected: (DateTime date) {
                                            selectedDate = date;
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Center(
                                        child: TextFormField(
                                          controller: batchNumberController,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(10.0)),
                                            ),
                                            hintStyle:
                                                const TextStyle(fontSize: 10.0),
                                            hintText: 'add_voucher_details.hint_batch_number'.tr,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.9),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            onPressed: () async {
                                              // Call the API
                                              String? accessToken =
                                                  Provider.of<AuthModel>(
                                                          context,
                                                          listen: false)
                                                      .token;
                                              var result = await purchaseProvider
                                                  .addPurchaseProductStockAPI(
                                                accessToken: accessToken ??
                                                    "", // Replace with actual access token
                                                purchaseItemId:
                                                    products.id.toString(),
                                                quantity:
                                                    quantityController.text,
                                                purchaseRate:
                                                    purchaseRateController.text,
                                                retailPrice:
                                                    retailPriceController.text,
                                                wholesalePrice:
                                                    wholesalePriceController
                                                        .text,
                                                wholesaleMinUnit:
                                                    wholesaleMinUnitController
                                                        .text,
                                                expiryDate: selectedDate != null
                                                    ? DateHelper.formatDate(
                                                        selectedDate!)
                                                    : '',
                                                batchNumber:
                                                    batchNumberController.text,
                                                unit: selectedUnit,
                                              );

                                              // Handle the API response
                                              if (result['status'] ==
                                                  'success') {
                                                // Show success message
                                                showScaffoldError(
                                                  context: context,
                                                  message:
                                                      'add_voucher_details.success_stock_updated'.tr,
                                                );
                                              } else {
                                                // Show error message
                                                showScaffoldError(
                                                  context: context,
                                                  message:
                                                      'add_voucher_details.error_stock_update_failed'.trParams({'message': result['message']}),
                                                );
                                              }
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
                      )),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: CustomRoundButton(
                      title: 'add_voucher_details.btn_back'.tr,
                      boxColor: Colors.white,
                      textColor: ColorManager.kPrimaryColor,
                      fct: () async {
                        sideBarController.index.value = 26;
                      },
                      height: 50,
                      width: size.width * 0.19,
                      fontSize: FontSize.s12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
