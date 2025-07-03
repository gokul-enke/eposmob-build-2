import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CouponInput extends StatelessWidget {
  final TextEditingController couponCodeController;
  final bool isCouponApplied;
  final VoidCallback onApplyCoupon;
  final VoidCallback onRemoveCoupon;

  const CouponInput({
    Key? key,
    required this.couponCodeController,
    required this.isCouponApplied,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BuildBoxShadowContainer(
            circleRadius: 7,
            alignment: Alignment.centerLeft,
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            padding: const EdgeInsets.only(left: 15),
            height: MediaQuery.of(context).size.height * .07,
            width: MediaQuery.of(context).size.width / 3,
            child: TextField(
              controller: couponCodeController,
              enabled: !isCouponApplied,
              decoration: InputDecoration(
                hintText: 'Apply Coupon',
                hintStyle: buildCustomStyle(
                  FontWeight.w500,
                  12,
                  0.27,
                  Colors.grey.withOpacity(.5),
                ),
                border: InputBorder.none,
              ),
              style: buildCustomStyle(
                FontWeight.w500,
                12,
                0.27,
                Colors.black.withOpacity(.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (isCouponApplied) // Show remove button if coupon is applied
          CustomRoundButton(
            title: "Remove",
            fct: onRemoveCoupon,
            fontSize: FontSize.s14,
            height: MediaQuery.of(context).size.height * .07,
            width: 100,
          )
        else
          CustomRoundButton(
            title: "Apply",
            fct: onApplyCoupon,
            fontSize: FontSize.s14,
            height: MediaQuery.of(context).size.height * .07,
            width: 100,
          ),
      ],
    );
  }
} 