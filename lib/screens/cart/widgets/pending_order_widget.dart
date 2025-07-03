import 'package:flutter/material.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_payment_row.dart';
import '../../../components/build_profile_picture.dart';
import '../../../components/build_round_button.dart';
import '../../../resources/asset_manager.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';

class PendingOrderWidget extends StatelessWidget {
  const PendingOrderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Expanded(
      child: Column(
        children: [
          BuildBoxShadowContainer(
            circleRadius: 7,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(top: 13.0, left: 8, right: 8),
            offsetValue: const Offset(1, 1),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Vincent Lodo\n',
                        style: ResponsiveWidget.isMobile(context)
                            ? buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s12, 0.30, ColorManager.textColor)
                            : buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s24, 0.35, ColorManager.textColor),
                        children: <TextSpan>[
                          TextSpan(
                            text: '26 Feb 2021, 16:50:32',
                            style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s13,
                                0.20,
                                ColorManager.blackWithOpacity50),
                          ),
                        ],
                      ),
                    ),
                    const BuildProfilePicture()
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: MediaQuery.of(context).size.width / 2.5,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: ColorManager.kPrimaryWithOpacity10,
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: 'Note\n',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s15, 0.23, ColorManager.kPrimaryColor),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Waiting for friends.',
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.18, Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: 3,
                      shrinkWrap: true,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          //horizontalTitleGap: 0,
                          minLeadingWidth: 0,
                          minVerticalPadding: 0,
                          contentPadding: EdgeInsets.zero,
                          visualDensity:
                              const VisualDensity(horizontal: 0, vertical: 0),

                          leading: Text(
                            '${index + 1}',
                            style: buildCustomStyle(FontWeightManager.regular,
                                FontSize.s15, 0.23, Colors.black),
                          ),

                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: 'MIGHTY ZINGER BOX\n',
                                  style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s13,
                                      0.20,
                                      Colors.black),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: '150 g',
                                      style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s9,
                                          0.13,
                                          ColorManager.blackWithOpacity50),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$25.00',
                                style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.21,
                                    ColorManager.blackWithOpacity50),
                              ),
                            ],
                          ),

                          trailing: WebsafeSvg.asset(
                            ImageAssets.oderlistCloseIcon,
                            fit: BoxFit.fill,
                          ),
                          //   ],
                        );
                      }),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14.0),
                    child: Column(
                      children: [
                        const BuildPaymentRow(
                          amount: "\$75.00",
                          title: "Net amount",
                          color: ColorManager.textColor,
                        ),
                        const BuildPaymentRow(
                          amount: "\$20.00",
                          title: "Discount",
                          color: ColorManager.textColor,
                        ),
                        const BuildPaymentRow(
                          amount: "\$20.00",
                          title: "Tax Amount",
                          color: ColorManager.textColor,
                        ),
                        const Divider(thickness: 2),
                        BuildPaymentRow(
                          amount: "\$115.00",
                          title: "Payable",
                          secondRowTextStyle: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s15,
                            0.23,
                            ColorManager.textColor,
                          ),
                          firstRowTextStyle: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s15,
                            0.23,
                            ColorManager.textColor,
                          ),
                          color: ColorManager.textColor,
                        ),
                        BuildPaymentRow(
                          amount: "\$100.00",
                          title: "Balance amount",
                          secondRowTextStyle: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.18,
                            ColorManager.textColorRed,
                          ),
                          firstRowTextStyle: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s15,
                            0.23,
                            ColorManager.textColorRed,
                          ),
                          color: ColorManager.textColorRed,
                        ),
                        const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CustomRoundButtonWithIcon(
                      title: "Resume",
                      size: size,
                      radius: 4,
                      fct: () {},
                      fontSize: FontSize.s12,
                      height: 40,
                      width: 120,
                      icon: const Icon(
                        Icons.play_circle_outline_outlined,
                        color: Colors.white,
                      ),
                    ),
                    CustomRoundButtonWithIcon(
                        radius: 4,
                        size: size,
                        icon: const Icon(
                          Icons.delete,
                          color: ColorManager.kPrimaryColor,
                        ),
                        boxColor: Colors.transparent,
                        borderColor: ColorManager.kPrimaryColor,
                        textColor: ColorManager.kPrimaryColor,
                        title: "Remove",
                        fct: () {},
                        fontSize: FontSize.s12,
                        height: 40,
                        width: 120),
                  ],
                ),
              ],
            ),
          ),
          BuildBoxShadowContainer(
            circleRadius: 7,
            margin: const EdgeInsets.only(
              top: 13.0,
              left: 8,
              right: 8,
              bottom: 13.0,
            ),
            padding: const EdgeInsets.all(20),
            offsetValue: const Offset(1, 1),
            child: Column(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Vincent Lodo\n',
                          style: ResponsiveWidget.isMobile(context)
                              ? buildCustomStyle(FontWeightManager.semiBold,
                                  FontSize.s12, 0.30, ColorManager.textColor)
                              : buildCustomStyle(FontWeightManager.semiBold,
                                  FontSize.s24, 0.35, ColorManager.textColor),
                          children: <TextSpan>[
                            TextSpan(
                              text: '26 Feb 2021, 16:50:32',
                              style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s13,
                                  0.20,
                                  ColorManager.blackWithOpacity50),
                            ),
                          ],
                        ),
                      ),
                      const BuildProfilePicture(),
                    ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
