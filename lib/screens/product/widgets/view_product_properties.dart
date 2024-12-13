import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_round_button.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';

class ViewProductPropertiesScreen extends StatelessWidget {
  final Function(int) navigateToScreen;
  const ViewProductPropertiesScreen(
      {super.key, required this.navigateToScreen});

  @override
  Widget build(BuildContext context) {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
    Size size = MediaQuery.of(context).size;

    GetProduct? getProduct = gridSelectionProvider.getProductDetails;
    List<Widget> buildProductProperties(List<ProductProp>? productProps) {
      if (productProps == null || productProps.isEmpty) {
        return [const Text("No properties available")];
      }

      return productProps.map((prop) {
        return ListTile(
          title: Text("${prop.propsCode}"),
          subtitle: Text(prop.masterValue.toString()),
          trailing: Text("Stock Applicable: ${prop.stockApplicable}"),
        );
      }).toList();
    }

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
                  const SizedBox(height: 50),
                  ...buildProductProperties(
                      getProduct?.productProps), // Display product properties
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: CustomRoundButton(
                          title: "Prev",
                          fct: () async {
                            navigateToScreen(1);
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
                            navigateToScreen(3);
                          },
                          height: 50,
                          width: size.width * 0.19,
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
