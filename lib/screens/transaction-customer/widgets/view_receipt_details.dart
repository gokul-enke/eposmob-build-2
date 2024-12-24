import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/models/receipt_details.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../providers/invoice_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewReceiptDetailsWidget extends StatelessWidget {
  const ViewReceiptDetailsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    InvoiceProvider invoiceProvider = Provider.of<InvoiceProvider>(context);

    ReceiptDetails? receiptDetails = invoiceProvider.getReceiptDetails;
    ReceiptData? receiptData = receiptDetails?.data;

    debugPrint("receiptData : ${receiptData.toString()}");

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
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: ListView(
            children: [
              CustomBackButton(
                onPressed: () {
                  sideBarController.index.value = 47;
                },
                text: 'All Receipts',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Receipt Details  ",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
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
                padding: const EdgeInsets.only(left: 20, top: 20),
                margin: const EdgeInsets.only(
                    top: 20, bottom: 0, left: 10, right: 10),
                child: Text(
                  " Details  ",
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s15,
                    0.30,
                    Colors.white,
                  ),
                ),
              ),
              BuildBoxShadowContainer(
                height: size.height,
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
                      title1: "Receipt Number",
                      content1: receiptData?.receiptNumber ?? "",
                      title2: "Company",
                      content2: receiptData?.company.name ?? "",
                    ),
                    BuildDetailRow(
                      title1: "Customer Name",
                      content1: receiptData?.customer.user.name ?? "",
                      title2: "Amount",
                      content2: receiptData?.amount ?? "",
                    ),
                    BuildDetailRow(
                      title1: "Payment Method",
                      content1: receiptData?.paymentMethod ?? "",
                      title2: "Status",
                      content2: receiptData?.receiptStatus ?? "",
                    ),
                    BuildDetailRow(
                      title1: "Payment Reference",
                      content1: receiptData?.paymentReference ?? "",
                      title2: "Date",
                      content2: receiptData?.createdAt.toString() ?? "",
                    ),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: CustomRoundButton(
                        title: "Back",
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () async {
                          sideBarController.index.value = 47;
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
      ),
    );
  }
}
