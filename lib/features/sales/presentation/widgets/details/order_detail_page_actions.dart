import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/responsive.dart';

class OrderDetailPageActions extends StatelessWidget {
  const OrderDetailPageActions(
      {super.key,
      required this.onPrint,
      required this.onShare,
      required this.onReturn,
      required this.onOrderStatus,
      required this.onPaymentStatus});
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onReturn;
  final VoidCallback onOrderStatus;
  final VoidCallback onPaymentStatus;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = isMobile ? (constraints.maxWidth - 10) / 2 : 168.0;
        final buttonHeight = isMobile ? 40.0 : 40.0;
        final buttonFontSize = isMobile ? FontSize.s11 : FontSize.s12;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: [
            CustomRoundButton(
              title: 'sales_order_details.btn_print'.tr,
              icon: const Icon(Icons.print_outlined,
                  size: 16, color: ColorManager.kPrimaryColor),
              boxColor: Colors.white,
              borderColor: ColorManager.kPrimaryColor,
              textColor: ColorManager.kPrimaryColor,
              fct: onPrint,
              height: buttonHeight,
              width: buttonWidth,
              fontSize: buttonFontSize,
            ),
            CustomRoundButton(
              title: 'sales_order_details.btn_share'.tr,
              icon: const Icon(Icons.share_outlined,
                  size: 16, color: Colors.blue),
              boxColor: Colors.white,
              borderColor: Colors.blue,
              textColor: Colors.blue,
              fct: onShare,
              height: buttonHeight,
              width: buttonWidth,
              fontSize: buttonFontSize,
            ),
            CustomRoundButton(
              title: 'sales_order_details.btn_return'.tr,
              icon: const Icon(Icons.assignment_return_outlined,
                  size: 16, color: Color(0xFFE53E3E)),
              boxColor: Colors.white,
              borderColor: const Color(0xFFE53E3E),
              textColor: const Color(0xFFE53E3E),
              fct: onReturn,
              height: buttonHeight,
              width: buttonWidth,
              fontSize: buttonFontSize,
            ),
            CustomRoundButton(
              title: 'sales_order_details.btn_order_status'.tr,
              icon: const Icon(Icons.local_shipping_outlined,
                  size: 16, color: Color(0xFF6A1B9A)),
              boxColor: Colors.white,
              borderColor: const Color(0xFF6A1B9A),
              textColor: const Color(0xFF6A1B9A),
              fct: onOrderStatus,
              height: buttonHeight,
              width: buttonWidth,
              fontSize: buttonFontSize,
            ),
            CustomRoundButton(
              title: 'sales_order_details.btn_payment_status'.tr,
              icon: const Icon(Icons.payments_outlined,
                  size: 16, color: Color(0xFF1E88E5)),
              boxColor: Colors.white,
              borderColor: const Color(0xFF1E88E5),
              textColor: const Color(0xFF1E88E5),
              fct: onPaymentStatus,
              height: buttonHeight,
              width: buttonWidth,
              fontSize: buttonFontSize,
            ),
          ],
        );
      },
    );
  }
}
