import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/models/invoice_details.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';

import '../../../providers/invoice_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewInvoiceDetailsWidget extends StatelessWidget {
  const ViewInvoiceDetailsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    InvoiceProvider invoiceProvider = Provider.of<InvoiceProvider>(
      context,
    );
    InvoiceDetails? invoiceDetails = invoiceProvider.getInvoiceDetails;

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
                  sideBarController.index.value = 21;
                },
                text: 'view_invoice.btn_invoice_list'.tr,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'view_invoice.page_title'.tr,
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
                  'view_invoice.section_details'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s15, 0.30, Colors.white),
                ),
              ),
              BuildBoxShadowContainer(
                height: size.height * 0.5, // Adjust height as needed
                margin: const EdgeInsets.only(
                    top: 0, bottom: 10, left: 10, right: 10),
                padding: const EdgeInsets.only(
                    top: 10, bottom: 10, left: 10, right: 10),
                circleRadius: 7,
                offsetValue: const Offset(1, 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text('view_invoice.col_invoice'.tr)),
                              DataColumn(label: Text('view_invoice.col_item_name'.tr)),
                              DataColumn(label: Text('view_invoice.col_quantity'.tr)),
                              DataColumn(label: Text('view_invoice.col_unit_amount'.tr)),
                              DataColumn(label: Text('view_invoice.col_tax'.tr)),
                              DataColumn(label: Text('view_invoice.col_total_amount'.tr)),
                            ],
                            rows: invoiceDetails?.invoiceItems.map((item) {
                                  return DataRow(cells: [
                                    DataCell(Text(item.invoiceId.toString())),
                                    DataCell(Text(item.itemName)),
                                    DataCell(Text(item.quantity.toString())),
                                    DataCell(Text(item.unitAmount)),
                                    DataCell(Text(item.tax)),
                                    DataCell(Text(item.totalAmount)),
                                  ]);
                                }).toList() ??
                                [],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: CustomRoundButton(
                        title: 'view_invoice.btn_back'.tr,
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: () async {
                          sideBarController.index.value = 21;
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
