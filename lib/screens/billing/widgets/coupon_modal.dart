import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:provider/provider.dart';

class CouponModal extends StatefulWidget {
  final String initialCouponCode;
  final bool isCouponApplied;
  final Function(String, bool) onCouponAction;

  const CouponModal({
    Key? key,
    required this.initialCouponCode,
    required this.isCouponApplied,
    required this.onCouponAction,
  }) : super(key: key);

  @override
  State<CouponModal> createState() => _CouponModalState();
}

class _CouponModalState extends State<CouponModal> {
  late TextEditingController couponController;
  late bool isCouponApplied;

  @override
  void initState() {
    super.initState();
    couponController = TextEditingController(text: widget.initialCouponCode);
    isCouponApplied = widget.isCouponApplied;
  }

  @override
  void dispose() {
    couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        color: Colors.white,
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Apply Coupon',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.21,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 15),
              height: 50,
              child: TextField(
                controller: couponController,
                enabled: !isCouponApplied,
                decoration: InputDecoration(
                  hintText: 'Enter Coupon Code',
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
                onTap: () {
                  // Select all text for easy replacement
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (couponController.text.isNotEmpty) {
                      couponController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: couponController.text.length,
                      );
                    }
                  });

                  Provider.of<KeyboardProvider>(context, listen: false).show(
                    'text',
                    couponController,
                    replaceOnFirstInput: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (isCouponApplied) ...[
                  Expanded(
                    child: CustomRoundButton(
                      title: "Remove",
                      fct: () {
                        widget.onCouponAction('', false);
                        Navigator.of(context).pop();
                      },
                      fontSize: FontSize.s14,
                      height: 45,
                      width: double.infinity,
                      boxColor: ColorManager.kButtonRed,
                      borderColor: ColorManager.kButtonRed,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: CustomRoundButton(
                      title: "Apply",
                      fct: () {
                        widget.onCouponAction(couponController.text, true);
                        Navigator.of(context).pop();
                      },
                      fontSize: FontSize.s14,
                      height: 45,
                      width: double.infinity,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
} 