import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/pages/sales_list_page.dart';

/// Compatibility entry point: both modes use the shared listing implementation.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key, this.isOnlineSales = false});
  final bool isOnlineSales;

  @override
  Widget build(BuildContext context) =>
      SalesListPage(isOnlineSales: isOnlineSales);
}
