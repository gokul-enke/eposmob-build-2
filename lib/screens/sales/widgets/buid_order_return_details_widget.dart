import 'package:flutter/material.dart';
import 'package:pos_machine/responsive.dart';
import '../../../components/build_container_box.dart';
import '../../../models/order_details.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class OrderReturnsWidget extends StatelessWidget {
  final OrderReturns? orderReturns;

  const OrderReturnsWidget({
    Key? key,
    required this.orderReturns,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (orderReturns == null) {
      return const Center(
        child: Text('No order returns available.'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuildBoxShadowContainer(
            circleRadius: 7,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(top: 13.0, left: 8, right: 8),
            offsetValue: const Offset(1, 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Return Order Details",
                  style: ResponsiveWidget.isMobile(context)
                      ? buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s12, 0.30, ColorManager.textColor)
                      : buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s24, 0.35, ColorManager.textColor),
                ),

                Text(
                  'Total Return Amount: ${orderReturns!.returnTotalAmount}',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 10),
                // Return Items List
                ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: orderReturns!.returnItems?.length ?? 0,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(), // Prevent scrolling
                  itemBuilder: (BuildContext context, int index) {
                    final item = orderReturns!.returnItems![index];
                    return ListTile(
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
                          Text(
                            item.productName ?? "NA",
                            style: buildCustomStyle(FontWeightManager.regular,
                                FontSize.s13, 0.20, Colors.black),
                          ),
                          Text(
                            'Quantity: ${item.quantity}',
                            style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.20,
                                ColorManager.blackWithOpacity50),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
