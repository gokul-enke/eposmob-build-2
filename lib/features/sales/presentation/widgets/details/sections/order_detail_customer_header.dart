import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_profile_picture.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_inputs.dart';

class OrderDetailCustomerHeader extends StatelessWidget {
  const OrderDetailCustomerHeader({super.key, required this.inputs});
  final OrderDetailInputs inputs;
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final nameStyle = isMobile
        ? buildCustomStyle(FontWeightManager.semiBold, FontSize.s14, 0.30,
            ColorManager.textColor)
        : buildCustomStyle(FontWeightManager.semiBold, FontSize.s24, 0.35,
            ColorManager.textColor);
    final dateStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s11 : FontSize.s13,
      0.20,
      ColorManager.blackWithOpacity50,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inputs.data.customerDetails?.name ?? 'NA',
            style: nameStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if ((inputs.data.customerDetails?.phone ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              inputs.data.customerDetails?.phone ?? '',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                ColorManager.blackWithOpacity50,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            DateHelper.formatInputToDisplay(
              inputs.data.orderDetailsModelData?.orderDate?.toString() ?? '',
            ),
            style: dateStyle,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              text:
                  '${inputs.data.customerDetails?.name ?? "NA"} - ${inputs.data.customerDetails?.phone ?? ""} \n',
              style: nameStyle,
              children: <TextSpan>[
                TextSpan(
                  text: DateHelper.formatInputToDisplay(
                    inputs.data.orderDetailsModelData?.orderDate?.toString() ??
                        '',
                  ),
                  style: dateStyle,
                ),
              ],
            ),
          ),
        ),
        const BuildProfilePicture(),
      ],
    );
  }
}
