import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_inputs.dart';

class OrderDetailSectionCard extends StatelessWidget {
  const OrderDetailSectionCard(
      {super.key, required this.inputs, required this.child});
  final OrderDetailInputs inputs;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.only(
        top: 8.0,
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
      ),
      offsetValue: const Offset(1, 1),
      child: child,
    );
  }
}
