import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/widgets/local_orders/confirmed_order_detail_modal.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

import 'local_sales_services.dart';

void showLocalSaleDetails(
    BuildContext context, SavedOrder order, LocalSalesServices services) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmedOrderDetailModal(order: order);
    },
  );
}
