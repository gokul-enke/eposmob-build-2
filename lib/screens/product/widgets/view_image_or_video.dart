import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';

import '../../../controllers/sidebar_controller.dart';
import '../../../models/get_product.dart';
import '../../../providers/grid_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ViewImageOrVideoScreen extends StatelessWidget {
  final Function(int) navigateToScreen;
  const ViewImageOrVideoScreen({super.key, required this.navigateToScreen});

  @override
  Widget build(BuildContext context) {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());
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
              blurRadius: 6,
              padding: const EdgeInsets.only(
                  left: 10.0, right: 20, top: 30, bottom: 10),
              offsetValue: const Offset(1, 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (getProduct != null &&
                      getProduct.attachment != null &&
                      getProduct.attachment!.isNotEmpty)
                    ...getProduct.attachment!.map((attach) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  left: 8.0,
                                  top: 10,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Title : ',
                                    style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s15,
                                        0.30,
                                        ColorManager.textColor),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: "${attach.title}",
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
                            ),
                            Flexible(
                              flex: 3,
                              child: BuildBoxShadowContainer(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                circleRadius: 5,
                                height: 100,
                                width: size.width * 0.2, // Responsive width
                                child: Image.network(
                                  attach.filePath ?? "",
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 8.0, left: 8.0, top: 10, right: 20),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Alt : ',
                                    style: buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s15,
                                        0.30,
                                        ColorManager.textColor),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: "${attach.alt}",
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
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: CustomRoundButton(
                          title: 'general.back'.tr,
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          fct: () async {
                            sideBarController.index.value = 14;
                          },
                          height: 50,
                          width: size.width *
                              0.25, // Adjusted width for responsiveness
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
