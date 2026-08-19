import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';

import '../../../models/get_product.dart';
import '../../../providers/grid_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewProductNameScreen extends StatelessWidget {
  final Function(int) navigateToScreen;
  const ViewProductNameScreen({super.key, required this.navigateToScreen});

  @override
  Widget build(BuildContext context) {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
    Size size = MediaQuery.of(context).size;

    GetProduct? getProduct = gridSelectionProvider.getProductDetails;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: size.height * 0.8,
            width: double.infinity,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              // margin: const EdgeInsets.only(bottom: 10),
              blurRadius: 6,
              padding: const EdgeInsets.only(
                  left: 10.0, right: 20, top: 30, bottom: 10),
              offsetValue: const Offset(1, 1),

              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              text: 'view_product_names.label_name_english'.tr,
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s15,
                                  0.30,
                                  ColorManager.textColor),
                              children: <TextSpan>[
                                TextSpan(
                                  text:
                                      "[en]: ${getProduct == null ? "" : getProduct.productName} ",
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              text: 'view_product_names.label_name_hindi'.tr,
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s15,
                                  0.30,
                                  ColorManager.textColor),
                              children: <TextSpan>[
                                TextSpan(
                                  text:
                                      "[hi]: ${getProduct == null ? "" : getProduct.productName} ", //getProduct.barcode
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8.0, left: 8.0, top: 10),
                          child: Text.rich(
                            TextSpan(
                              text: 'view_product_names.label_name_arabic'.tr,
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s15,
                                  0.30,
                                  ColorManager.textColor),
                              children: <TextSpan>[
                                TextSpan(
                                  text:
                                      "[ar]: ${getProduct == null ? "" : getProduct.productName} ",
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s15,
                                      0.30,
                                      ColorManager.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: CustomRoundButton(
                            title: 'view_product_names.btn_prev'.tr,
                            fct: () async {
                              navigateToScreen(0);
                              // sideBarController.index.value = 14;
                            },
                            height: 50,
                            width: size.width * 0.19,
                            fontSize: FontSize.s12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: CustomRoundButton(
                            title: 'view_product_names.btn_next'.tr,
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: () async {
                              navigateToScreen(2);
                              //   sideBarController.index.value = 14;
                            },
                            height: 50,
                            width: size.width * 0.19,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}
