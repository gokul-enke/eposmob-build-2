import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class OrderStatusRefundField extends StatelessWidget {
  const OrderStatusRefundField({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'change_order_status.refund_amount'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.27,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d*\.?\d{0,3}$'),
            ),
          ],
          decoration: InputDecoration(
            hintText: 'change_order_status.hint_refund_amount'.tr,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ColorManager.kPrimaryColor),
            ),
          ),
        ),
      ]);
}
