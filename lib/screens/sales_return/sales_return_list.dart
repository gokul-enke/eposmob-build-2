import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales_returns/presentation/pages/sales_return_list_page.dart';

/// Compatibility entry point; inner return workflows retain their screens.
class SalesReturnPage extends StatelessWidget {
  const SalesReturnPage({super.key});
  @override
  Widget build(BuildContext context) => const SalesReturnListPage();
}
