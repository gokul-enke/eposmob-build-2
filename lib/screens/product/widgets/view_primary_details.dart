import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';

import '../../../models/get_product.dart';
import '../../../providers/grid_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewPrimaryDetailsScreen extends StatelessWidget {
  final Function(int) navigateToScreen;
  const ViewPrimaryDetailsScreen({super.key, required this.navigateToScreen});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(
      context,
    );
    
    GetProduct? getProduct = gridSelectionProvider.getProductDetails;
    // debugPrint(getProduct == null ? "getProduct" : getProduct.productName);

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        buildRowWidget(
                          size: size,
                          seconfTitle: "Product Slug",
                          secondValue:
                              '${getProduct == null ? "" : getProduct.productSlug}',
                          firstTitle: "Category",
                          firstValue:
                              '${getProduct == null ? "" : getProduct.category!.name}',
                          thirdTitle: "Unit",
                          thirdValue:
                              '${getProduct == null ? "" : getProduct.unit}',
                        ),
                        buildRowWidget(
                          size: size,
                          firstTitle: "Name",
                          firstValue:
                              '${getProduct == null ? "" : getProduct.productName}',
                          seconfTitle: "Barcode",
                          secondValue: getProduct == null ? "" : "barcode",
                          thirdTitle: "Price",
                          thirdValue:
                              '${getProduct == null ? "" : getProduct.price!.price}',
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 8.0, left: 8.0, top: 10),
                      child: Text.rich(
                        TextSpan(
                          text: 'Currency : ',
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s15, 0.30, ColorManager.textColor),
                          children: <TextSpan>[
                            TextSpan(
                              text:
                                  '${getProduct == null ? "" : getProduct.currency}',
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s15, 0.30, ColorManager.textColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: CustomRoundButton(
                            title: "Next",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: () async {
                              navigateToScreen(1);
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

  Widget buildRowWidget(
          {required String firstTitle,
          required String thirdTitle,
          required String thirdValue,
          required String firstValue,
          required String seconfTitle,
          required String secondValue,
          required Size size}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, top: 10),
            child: SizedBox(
              width: size.width / 3,
              child: Text.rich(
                TextSpan(
                  text: '$firstTitle : ',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s15, 0.30, ColorManager.textColor),
                  children: <TextSpan>[
                    TextSpan(
                      text: firstValue,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s15, 0.30, ColorManager.textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, top: 10),
            child: SizedBox(
              width: size.width / 3,
              child: Text.rich(
                TextSpan(
                  text: '$seconfTitle : ',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s15, 0.30, ColorManager.textColor),
                  children: <TextSpan>[
                    TextSpan(
                      text: secondValue, //getProduct.barcode
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s15, 0.30, ColorManager.textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, top: 10),
            child: Text.rich(
              TextSpan(
                text: '$thirdTitle : ',
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s15, 0.30, ColorManager.textColor),
                children: <TextSpan>[
                  TextSpan(
                    text: thirdValue, //getProduct.barcode
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s15, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
