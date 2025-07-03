import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

class AddProductNamePageScreen extends StatefulWidget {
  final Function(int) navigateToScreen;
  const AddProductNamePageScreen({super.key, required this.navigateToScreen});

  @override
  State<AddProductNamePageScreen> createState() =>
      _AddProductNamePageScreenState();
}

class _AddProductNamePageScreenState extends State<AddProductNamePageScreen> {
  final productNameEnglishController = TextEditingController();
  final productNameHindiController = TextEditingController();
  final productNameArabicController = TextEditingController();

  String? englishError;
  String? hindiError;
  String? arabicError;

  void validateFields() {
    setState(() {
      englishError = productNameEnglishController.text.isEmpty
          ? "This field is required"
          : null;
      hindiError = productNameHindiController.text.isEmpty
          ? "This field is required"
          : null;
      arabicError = productNameArabicController.text.isEmpty
          ? "This field is required"
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
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
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  errorText: englishError,
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
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  errorText: hindiError,
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
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              errorText: arabicError,
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
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            fct: () async {
                              validateFields();
                              if (englishError == null &&
                                  hindiError == null &&
                                  arabicError == null) {
                                int? productId =
                                    gridSelectionProvider.getProductId;
                                if (productId == null) {
                                  showScaffold(
                                    context: context,
                                    message: 'Failed',
                                  );
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
                                      .addProductNamesAPI(
                                          productId: "$productId",
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
                                    } else {
                                      Navigator.pop(context);
                                      showScaffold(
                                        context: context,
                                        message: '${value["message"]}',
                                      );
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
