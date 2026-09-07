import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_detail_row.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../models/list_transaction.dart';

import '../../../providers/invoice_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewTransactionDetailsWidget extends StatelessWidget {
  const ViewTransactionDetailsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    InvoiceProvider invoiceProvider = Provider.of<InvoiceProvider>(
      context,
    );
    ListTransaction? listTransaction = invoiceProvider.getListTransaction;
    // debugPrint(listTransaction == null
    //     ? "listTransaction"
    //     : listTransaction.accountName);
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
                sideBarController.index.value = 23;
              },
              text: 'view_transaction_details.btn_all_transactions'.tr,
              // Optionally, you can customize the color and size
              // color: ColorManager.customColor,
              // size: 20.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'view_transaction_details.page_title'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
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
                'view_transaction_details.section_details'.tr,
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
                      title1:
                          'view_transaction_details.label_order_number'.tr,
                      content1: listTransaction?.orderId.toString() ?? "",
                      title2: 'view_transaction_details.label_transaction_type'
                          .tr,
                      content2: listTransaction?.transactionType ?? "",
                    ),
                    BuildDetailRow(
                      title1:
                          'view_transaction_details.label_customer_name'.tr,
                      content1: listTransaction?.customerName ?? "",
                      title2: 'view_transaction_details.label_amount'.tr,
                      content2: listTransaction?.amount ?? "",
                    ),
                    BuildDetailRow(
                      title1: 'view_transaction_details.label_type'.tr,
                      content1: listTransaction?.type ?? "",
                      title2: 'view_transaction_details.label_status'.tr,
                      content2: listTransaction?.status ?? "",
                    ),
                    BuildDetailRow(
                      title1: 'view_transaction_details.label_date'.tr,
                      content1: listTransaction?.reference ?? "",
                      title2:
                          'view_transaction_details.label_invoice_number'.tr,
                      content2: listTransaction?.transactionComment ?? "",
                    ),
                    BuildDetailRow(
                      title1: 'view_transaction_details.label_reference'.tr,
                      content1: listTransaction?.reference ?? "",
                      title2:
                          'view_transaction_details.label_payment_method'.tr,
                      content2: listTransaction?.paymentMethod ?? "",
                    ),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: CustomRoundButton(
                        title: 'view_transaction_details.btn_back'.tr,
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () async {
                          sideBarController.index.value = 23;
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
