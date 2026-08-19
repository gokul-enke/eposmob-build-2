import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/build_container_box.dart';
import '../../components/build_title.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class LoyalityCardScreen extends StatelessWidget {
  const LoyalityCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchTextController = TextEditingController();
    final cardNumberTextController = TextEditingController();
    final firstNameTextController = TextEditingController();
    final lastNameTextController = TextEditingController();
    List<String> card = ["Master", "Visa", "GPay", "PhonePe"];
    String? cardValue;
    String? categoryValue;
    List<String> category = ["Mobile Payment", "Online", "Cash", "cheque"];
    Size size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'loyality.page_title'.tr,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
            SizedBox(
              height: size.height * 1.2,
              child: BuildBoxShadowContainer(
                circleRadius: 7,
                margin: const EdgeInsets.only(bottom: 10, top: 20),
                blurRadius: 6,
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20,
                  top: 30,
                ),
                offsetValue: const Offset(1, 1),
                child: Column(
                  // shrinkWrap: true,
                  children: [
                    BuildBoxShadowContainer(
                      padding: const EdgeInsets.only(
                          left: 15, right: 15, top: 20, bottom: 45),
                      circleRadius: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: size.height * 0.07,
                            width: size.width * 0.5,
                            child: TextField(
                              controller: searchTextController,
                              cursorColor: ColorManager.kPrimaryColor,
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'loyality.hint_search'.tr,
                                  hintStyle: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.18,
                                      ColorManager.textColor),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.black,
                                    size: 35,
                                  ),
                                  prefixIconColor: Colors.black),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(thickness: 2),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: 'loyality.label_first_name'.tr,
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s18,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    circleRadius: 7,
                                    alignment: Alignment.centerLeft,
                                    margin: const EdgeInsets.only(
                                        left: 15, right: 0),
                                    padding: const EdgeInsets.only(left: 15),
                                    height: size.height * .07,
                                    width: size.width / 3.05,
                                    child: TextFormField(
                                      //  initialValue: initialValue,
                                      keyboardType: TextInputType.text,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                      ),
                                      controller: firstNameTextController,
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
                                  BuildTextTile(
                                    title: 'loyality.label_last_name'.tr,
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s18,
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
                                    width: size.width / 3.05,
                                    child: TextFormField(
                                      //  initialValue: initialValue,
                                      keyboardType: TextInputType.text,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                      ),
                                      controller: lastNameTextController,
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: 'loyality.label_select_category'.tr,
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s18,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    circleRadius: 5,
                                    margin: const EdgeInsets.only(
                                        right: 10,
                                        left: 15,
                                        top: 0,
                                        bottom: 20),
                                    //  height: size.height * .07,
                                    width: size.width / 3.17, //3.05
                                    padding: const EdgeInsets.only(
                                        right: 20, left: 20, top: 5, bottom: 5),
                                    child: DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField<String>(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.black,
                                      ),
                                      isExpanded: false,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                      ),
                                      hint: Text(
                                        "",
                                        style: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s13,
                                            0.27,
                                            ColorManager.textColor
                                                .withOpacity(0.5)),
                                      ),
                                      value: categoryValue,
                                      items: category
                                          .map((e) => DropdownMenuItem<String>(
                                                value: e,
                                                child: Text(
                                                  e,
                                                  style: buildCustomStyle(
                                                      FontWeight.normal,
                                                      FontSize.s12,
                                                      0.27,
                                                      ColorManager.textColor),
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        // setState(() {
                                        //   selectedGanvinLocation = value;
                                        //   pincodeId = value == null ? 0 : value.id;
                                        // });
                                      },
                                    )),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildTextTile(
                                    title: 'loyality.label_select_card'.tr,
                                    textStyle: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s18,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  BuildBoxShadowContainer(
                                    circleRadius: 5,
                                    margin: const EdgeInsets.only(
                                        right: 10,
                                        left: 15,
                                        top: 0,
                                        bottom: 20),
                                    //  height: size.height * .07,
                                    width: size.width / 3.05,
                                    padding: const EdgeInsets.only(
                                        right: 20, left: 20, top: 5, bottom: 5),
                                    child: DropdownButtonHideUnderline(
                                        child: DropdownButtonFormField<String>(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.black,
                                      ),
                                      isExpanded: false,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                      ),
                                      hint: Text(
                                        "",
                                        style: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s13,
                                            0.27,
                                            ColorManager.textColor
                                                .withOpacity(0.5)),
                                      ),
                                      value: cardValue,
                                      items: card
                                          .map((e) => DropdownMenuItem<String>(
                                                value: e,
                                                child: Text(
                                                  e,
                                                  style: buildCustomStyle(
                                                      FontWeight.normal,
                                                      FontSize.s12,
                                                      0.27,
                                                      ColorManager.textColor),
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        // setState(() {
                                        //   selectedGanvinLocation = value;
                                        //   pincodeId = value == null ? 0 : value.id;
                                        // });
                                      },
                                    )),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              BuildTextTile(
                                title: 'loyality.label_card_number'.tr,
                                textStyle: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s18,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              const Icon(
                                Icons.sync,
                                color: ColorManager.kPrimaryColor,
                              ),
                            ],
                          ),
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            color: ColorManager.kTextFieldColor25,
                            alignment: Alignment.centerLeft,
                            margin: const EdgeInsets.only(left: 15, right: 10),
                            padding: const EdgeInsets.only(left: 20),
                            height: size.height * .07,
                            child: TextFormField(
                              //  initialValue: initialValue,
                              keyboardType: TextInputType.text,
                              cursorColor: ColorManager.kPrimaryColor,
                              decoration: InputDecoration(
                                hintText: "21423345465466",
                                helperStyle: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s12,
                                    0.18,
                                    ColorManager.textColor.withOpacity(0.5)),
                                border: InputBorder.none,
                              ),
                              controller: cardNumberTextController,
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
                    ),
                    const SizedBox(height: 15),
                    ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int index) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: index % 2 == 0
                                  ? ColorManager.containerShadowColorForList
                                  : null,
                            ),
                            child: ListTile(
                              minLeadingWidth: 0,
                              minVerticalPadding: 0,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: const VisualDensity(
                                  horizontal: 0, vertical: 0),
                              leading: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                    Radius.elliptical(21, 21)),
                                child: Image.asset(
                                  ImageAssets.profileAvatarIcon,
                                ),
                              ),
                              title: RichText(
                                text: TextSpan(
                                  text: 'John Doe\n',
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s15,
                                      0.23,
                                      ColorManager.textColor),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: 'Johndoe.@gmail.com',
                                      style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.18,
                                          Colors.black.withOpacity(0.5)),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Text(
                                '16/02/2022',
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s15,
                                    0.21,
                                    ColorManager.textColor),
                              ),
                            ),
                          );
                        }),
                  ],
                ),
              ),
            )
          ])),
    );
  }
}
