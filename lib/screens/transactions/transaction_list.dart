import 'package:flutter/material.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/customer_ledger/presentation/pages/customer_ledger_list_page.dart';

class CustomerTransactionListScreen extends StatelessWidget {
  const CustomerTransactionListScreen({super.key, this.export});
  final ExportController? export;
  static const desktopFiltersKey = CustomerLedgerListPage.desktopFiltersKey;
  static const mobileFiltersKey = CustomerLedgerListPage.mobileFiltersKey;
  static const filterToggleKey = CustomerLedgerListPage.filterToggleKey;
  static const exportKey = CustomerLedgerListPage.exportKey;
  static const refreshKey = CustomerLedgerListPage.refreshKey;
  static const dateFieldKey = CustomerLedgerListPage.dateFieldKey;
  @override
  Widget build(BuildContext context) => CustomerLedgerListPage(export: export);
}
