import 'package:flutter/material.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_desktop_cart_items_table.dart';
import 'order_detail_inputs.dart';
import 'order_detail_mobile_cart_items_list.dart';

class OrderDetailCartItemsTable extends StatelessWidget {
  const OrderDetailCartItemsTable(this.currency,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String currency;
  @override
  Widget build(BuildContext context) {
    if (ResponsiveWidget.isMobile(context)) {
      return OrderDetailMobileCartItemsList(currency, inputs: inputs);
    }

    final table = OrderDetailDesktopCartItemsTable(currency, inputs: inputs);
    if (ResponsiveWidget.isTablet(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: table,
    );
  }
}
