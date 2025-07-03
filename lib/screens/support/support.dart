import 'package:flutter/material.dart';

import '../../components/build_container_box.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                "Support ",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
              SizedBox(
                height: size.height * 0.8,
                width: double.infinity,
                child: const BuildBoxShadowContainer(
                  circleRadius: 7,
                  margin: EdgeInsets.only(bottom: 10, top: 20),
                  blurRadius: 6,
                  padding: EdgeInsets.only(
                    left: 20.0,
                    right: 20,
                    top: 30,
                  ),
                  offsetValue: Offset(1, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [],
                  ),
                ),
              )
            ])),
      ),
    );
  }
}
