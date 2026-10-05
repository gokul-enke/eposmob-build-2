import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';

import 'show_detail_share_options.dart';

Future<void> shareDetailOrder(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  await showDetailShareOptions(context, controller, services);
}
