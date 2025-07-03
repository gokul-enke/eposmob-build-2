import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:provider/provider.dart';

import '../../../../components/build_container_box.dart';
import '../../../../components/build_dialog_box.dart';
import '../../../../components/build_round_button.dart';
import '../../../../components/build_title.dart';
import '../../../../controllers/sidebar_controller.dart';

import '../../../../providers/auth_model.dart';
import '../../../../providers/grid_provider.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';

class EditProductNamePageScreen extends StatefulWidget {
  final Function(int) navigateToScreen;
  const EditProductNamePageScreen({super.key, required this.navigateToScreen});

  @override
  State<EditProductNamePageScreen> createState() =>
      _EditProductNamePageScreenState();
}

class _EditProductNamePageScreenState extends State<EditProductNamePageScreen> {
  @override
  Widget build(BuildContext context) {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    GetProduct? getProduct = gridSelectionProvider.getProductDetails;
    final TextEditingController productNameEnglishController =
        TextEditingController(text: getProduct?.names?.en ?? '');
    final TextEditingController productNameHindiController =
        TextEditingController(text: getProduct?.names?.hi ?? '');
    final TextEditingController productNameArabicController =
        TextEditingController(text: getProduct?.names?.ar ?? '');

    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());

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

              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildTextTile(
                              title: "Product Name - English (US)*",
                              textStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 05, vertical: 0),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width / 3,
                              child: TextFormField(
                                keyboardType: TextInputType.text,
                                cursorColor: ColorManager.kPrimaryColor,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                controller: productNameEnglishController,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildTextTile(
                              title: "Product Name - Hindi(IND)*",
                              textStyle: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              margin: const EdgeInsets.only(left: 20),
                              padding: const EdgeInsets.only(left: 15),
                              height: size.height * .07,
                              width: size.width / 3,
                              child: TextFormField(
                                keyboardType: TextInputType.text,
                                cursorColor: ColorManager.kPrimaryColor,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                controller: productNameHindiController,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildTextTile(
                          title: "Product Name - Arabic(AR)*",
                          textStyle: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s14,
                            0.27,
                            Colors.black.withOpacity(0.6),
                          ),
                        ),
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 0),
                          padding: const EdgeInsets.only(left: 15),
                          height: size.height * .07,
                          width: size.width / 3,
                          child: TextFormField(
                            keyboardType: TextInputType.text,
                            cursorColor: ColorManager.kPrimaryColor,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            controller: productNameArabicController,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.27,
                              ColorManager.textColor.withOpacity(.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: CustomRoundButton(
                            title: "Prev",
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: () async {
                              widget.navigateToScreen(0);
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
                            title: "Next",
                            fct: () async {
                              if (getProduct!.productId == null) {
                                showScaffold(
                                  context: context,
                                  message: 'Failed',
                                );
                              } else {
                                if (productNameArabicController.text.isEmpty ||
                                    productNameHindiController.text.isEmpty ||
                                    productNameArabicController.text.isEmpty) {
                                  showScaffold(
                                    context: context,
                                    message: 'Please Fill the Required Fields',
                                  );
                                  sideBarController.index.value = 14;
                                } else {
                                  showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) {
                                        return const Center(
                                          child: CircularProgressIndicator
                                              .adaptive(),
                                        );
                                      });
                                  String? accessToken = Provider.of<AuthModel>(
                                          context,
                                          listen: false)
                                      .token;
                                  debugPrint(
                                      "accessToken From AuthModel $accessToken");
                                  gridSelectionProvider
                                      .editProductNamesAPI(
                                          productId: "${getProduct.productId}",
                                          productNameEnglish:
                                              productNameEnglishController.text,
                                          productNameHindi:
                                              productNameHindiController.text,
                                          productNameArabic:
                                              productNameArabicController.text,
                                          accessToken: accessToken ?? "")
                                      .then((value) {
                                    if (value["status"] == "success") {
                                      showScaffold(
                                        context: context,
                                        message: '${value["message"]}',
                                      );

                                      Navigator.pop(context);
                                      widget.navigateToScreen(2);
                                      productNameArabicController.clear();
                                      productNameEnglishController.clear();
                                      productNameHindiController.clear();
                                    } else {
                                      Navigator.pop(context);
                                      showScaffold(
                                        context: context,
                                        message: '${value["message"]}',
                                      );
                                      // sideBarController.index.value = 14;
                                    }
                                  });
                                }
                              }
                            },
                            height: 50,
                            width: size.width * 0.19,
                            fontSize: FontSize.s12,
                          ),
                        ),
                        // Padding(
                        //   padding: const EdgeInsets.only(left: 10.0),
                        //   child: CustomRoundButton(
                        //     title: "Next",
                        //     boxColor: Colors.white,
                        //     textColor: ColorManager.kPrimaryColor,
                        //     fct: () async {
                        //       widget.navigateToScreen(2);
                        //       // sideBarController.index.value = 14;
                        //     },
                        //     height: 50,
                        //     width: size.width * 0.19,
                        //     fontSize: FontSize.s12,
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
