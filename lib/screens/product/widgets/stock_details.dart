import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_detail_row.dart';
import 'package:pos_machine/models/list_stock.dart' as stock_models;

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../controllers/sidebar_controller.dart';

import '../../../providers/stock_provider.dart';

import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class StockDetailsWidget extends StatelessWidget {
  const StockDetailsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
    StockProvider stockProvider =
        Provider.of<StockProvider>(context);

    stock_models.ListStockModelData? stockDetails =
        stockProvider.viewStockModelData;

    List<Widget> buildProductProperties(productProps) {
      if (productProps == null || productProps.isEmpty) {
        return [
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text("No properties available"),
          )
        ];
      }

      return productProps.map<Widget>((prop) {
        return BuildDetailRow(
          title1: prop['prop_code'] ?? "",
          content1: prop['prop_value']?.toString() ?? "",
          title2: "",
          content2: "",
        );
      }).toList();
    }

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
                sideBarController.index.value = 15;
              },
              text: 'All Stocks',
              // Optionally, you can customize the color and size
              // color: ColorManager.customColor,
              // size: 20.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  " Stock Details  ",
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
                        sideBarController.index.value = 15;
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
                " Show Stock",
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
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Product Primary Details",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s18, 0.30, ColorManager.textColor),
                      ),
                      // BuildDetailRow(
                      //   title1: "Product Name",
                      //   content1: stockDetails?.productName ?? "",
                      //   title2: "Product Slug",
                      //   content2: stockDetails?.product?.slug ?? "",
                      // ),
                      // BuildDetailRow(
                      //   title1: "Product Price",
                      //   content1:
                      //       stockDetails?.product?.price?.toString() ?? "",
                      //   title2: "Available Stock",
                      //   content2: stockDetails?.quantity?.toString() ?? "",
                      // ),
                      // BuildDetailRow(
                      //   title1: "Sell Currency",
                      //   content1: stockDetails?.product?.currency ?? "",
                      //   title2: "",
                      //   content2: "",
                      // ),
                      // const SizedBox(height: 20),
                      // Text(
                      //   "Product Stock Details",
                      //   style: buildCustomStyle(FontWeightManager.semiBold,
                      //       FontSize.s18, 0.30, ColorManager.textColor),
                      // ),
                      // BuildDetailRow(
                      //   title1: "Store Name",
                      //   content1: stockDetails?.storeName ?? "",
                      //   title2: "Product Quantity",
                      //   content2: stockDetails?.quantity?.toString() ?? "",
                      // ),
                      BuildDetailRow(
                        title1: "Product Unit",
                        content1: stockDetails?.unit ?? "",
                        title2: "Purchase Rate",
                        content2: stockDetails?.purchaseRate?.toString() ?? "",
                      ),
                      BuildDetailRow(
                        title1: "Retail Price",
                        content1: stockDetails?.retailPrice?.toString() ?? "",
                        title2: "Wholesale Price",
                        content2:
                            stockDetails?.wholesalePrice?.toString() ?? "",
                      ),
                      // BuildDetailRow(
                      //   title1: "Wholesale Min Unit",
                      //   content1:
                      //       stockDetails?.wholesaleMinUnit?.toString() ?? "",
                      //   title2: "Expiry Date",
                      //   content2: stockDetails?.expiryDate ?? "",
                      // ),
                      // BuildDetailRow(
                      //   title1: "Batch Number",
                      //   content1: stockDetails?.batchNumber ?? "",
                      //   title2: "",
                      //   content2: "",
                      // ),
                      const SizedBox(height: 20),
                      Text(
                        "Product Properties",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s18, 0.30, ColorManager.textColor),
                      ),
                      // ...buildProductProperties(stockDetails?.stockProperties),
                      const SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: CustomRoundButton(
                          title: "Back",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          fct: () async {
                            sideBarController.index.value = 15;
                          },
                          height: 50,
                          width: size.width * 0.19,
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    ));
  }
}
