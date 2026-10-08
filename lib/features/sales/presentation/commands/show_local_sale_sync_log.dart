import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/widgets/local_orders/local_sale_sync_log_dialog.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

import 'local_sales_services.dart';

void showLocalSaleSyncLog(
    BuildContext context, String localOrderId, LocalSalesServices services) {
  showDialog(
    context: context,
    builder: (_) => ChangeNotifierProvider<LocalSaleSyncService>.value(
      value: services.sync,
      child: LocalSaleSyncLogDialog(localOrderId: localOrderId),
    ),
  );
}
