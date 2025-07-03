import 'package:flutter/material.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class OrderPageHeader extends StatelessWidget {
  const OrderPageHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final bool isEditingOrder = localProductProvider.currentOrder != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEditingOrder ? 'Edit Order' : 'New Order',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
          ],
        ),
        Text(
          isEditingOrder
              ? 'Order No #${localProductProvider.currentOrder!.orderNumber}'
              : 'Order No #00000',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0.18,
              ColorManager.textColor),
        ),
      ],
    );
  }
} 