import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_title.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class ChangePasswordWidget extends StatelessWidget {
  final Size size;
  const ChangePasswordWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final passwordTextController = TextEditingController();
    final confirmPasswordTextController = TextEditingController();
    return Expanded(
      child: BuildBoxShadowContainer(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(15),
          height: size.height * 0.75, //180,
          // width: 220,
          circleRadius: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'profile.change_password_title'.tr,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s15, 0.23, ColorManager.textColor),
              ),
              const SizedBox(height: 20),
              Text(
                'profile.change_password_subtitle'.tr,
                style: TextStyle(
                    fontWeight: FontWeightManager.regular,
                    fontFamily: FontConstants.fontFamily,
                    fontSize: FontSize.s10,
                    letterSpacing: 0.13,
                    color: ColorManager.blackWithOpacity50),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BuildTitle(
                        title: 'profile.field_password'.tr,
                        textStyle: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s10,
                          0.16,
                          Colors.black.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      BuildBoxShadowContainer(
                        circleRadius: 7,
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.only(
                            top: 5, left: 0, right: 10, bottom: 20),
                        padding: const EdgeInsets.only(left: 15),
                        height: size.height * .07,
                        width: size.width / 5.5,
                        child: TextFormField(
                          //  initialValue: initialValue,
                          keyboardType: TextInputType.text,
                          cursorColor: ColorManager.kPrimaryColor,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "********",
                            hintStyle: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s10,
                              0.16,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                          controller: passwordTextController,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s13,
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
                      BuildTitle(
                        title: 'profile.field_confirm_password'.tr,
                        textStyle: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s10,
                          0.16,
                          Colors.black.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      BuildBoxShadowContainer(
                        circleRadius: 7,
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.only(
                            top: 5, left: 10, right: 0, bottom: 20),
                        padding: const EdgeInsets.only(left: 15),
                        height: size.height * .07,
                        width: size.width / 5.5,
                        child: TextFormField(
                          //  initialValue: initialValue,

                          keyboardType: TextInputType.text,
                          cursorColor: ColorManager.kPrimaryColor,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "********",
                            hintStyle: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s10,
                              0.16,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                          controller: confirmPasswordTextController,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s13,
                            0.27,
                            ColorManager.textColor.withOpacity(.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              RoundButton(
                  radius: 14, title: 'profile.btn_reset_password'.tr, fct: () {}, size: size)
            ],
          )),
    );
  }
}
