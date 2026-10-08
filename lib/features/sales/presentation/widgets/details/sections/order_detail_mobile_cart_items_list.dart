import 'package:flutter/material.dart';

import 'order_detail_inputs.dart';
import 'order_detail_mobile_cart_item_card.dart';

class OrderDetailMobileCartItemsList extends StatelessWidget {
  const OrderDetailMobileCartItemsList(this.currency,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final String currency;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          for (int index = 0;
              index < (inputs.data.cartItem?.length ?? 0);
              index++) ...[
            if (index > 0) const SizedBox(height: 8),
            OrderDetailMobileCartItemCard(
                index, inputs.data.cartItem![index], currency,
                inputs: inputs),
          ],
        ],
      ),
    );
  }
}
