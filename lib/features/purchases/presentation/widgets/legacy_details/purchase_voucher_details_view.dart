import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../navigation/purchase_navigation.dart';

part 'purchase_voucher_details_table.dart';

class LegacyPurchaseVoucherDetailsView extends StatelessWidget {
  const LegacyPurchaseVoucherDetailsView(
      {super.key,
      required this.voucherDetails,
      required this.listPurchaseItems,
      required this.store,
      required this.supplier,
      required this.productName});
  final VoucherDetail? voucherDetails;
  final List<PurchaseItem>? listPurchaseItems;
  final String store;
  final String supplier;
  final String? Function(int) productName;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Filter listPurchaseItems based on purchaseId in voucherDetails
    List<PurchaseItem>? filteredItems = listPurchaseItems?.where((item) {
      return item.purchaseId == voucherDetails?.purchaseId;
    }).toList();
    debugPrint(
        voucherDetails == null ? "viewCategory" : voucherDetails?.purchaseDate);
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
                PurchaseNavigation.openLegacyVouchers();
              },
              text: 'view_voucher.btn_all_vouchers'.tr,
              // Optionally, you can customize the color and size
              // color: ColorManager.customColor,
              // size: 20.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'view_voucher.page_title'.tr,
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
                        PurchaseNavigation.openLegacyList();
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
                'view_voucher.section_title'.tr,
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
                      title1: 'view_voucher.label_purchase_date'.tr,
                      content1: voucherDetails?.purchaseDate ?? "",
                      title2: 'view_voucher.label_store'.tr,
                      content2: store,
                    ),
                    BuildDetailRow(
                      title1: 'view_voucher.label_voucher_number'.tr,
                      content1: voucherDetails?.voucherNumber ?? "",
                      title2: 'view_voucher.label_amount'.tr,
                      content2: voucherDetails?.amountTotal?.toString() ?? "",
                    ),
                    BuildDetailRow(
                      title1: 'view_voucher.label_tax'.tr,
                      content1: voucherDetails?.taxAmount ?? "",
                      title2: 'view_voucher.label_currency'.tr,
                      content2: voucherDetails?.currency ?? "",
                    ),
                    BuildDetailRow(
                      title1: 'view_voucher.label_supplier'.tr,
                      content1: supplier,
                      title2: "",
                      content2: "",
                    ),
                    BuildBoxShadowContainer(
                        height: size.height / 2.5, //120,
                        width: size.width,
                        margin: const EdgeInsets.only(top: 20),
                        circleRadius: 7,
                        offsetValue: const Offset(1, 1),
                        child: SingleChildScrollView(
                          child: _buildItemsTable(filteredItems),
                        )),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: CustomRoundButton(
                        title: 'view_voucher.btn_back'.tr,
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () async {
                          PurchaseNavigation.openLegacyVouchers();
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
}
